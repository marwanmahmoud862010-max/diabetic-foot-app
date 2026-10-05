const ALLOWED_METHODS = ['POST', 'OPTIONS'];

function applyCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', ALLOWED_METHODS.join(', '));
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Access-Control-Max-Age', '86400');
}

function guard(req, res) {
  applyCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return true;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return true;
  }
  return false;
}

function readBody(req) {
  const raw = req.body;
  if (!raw) return {};
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch (_) {
      return {};
    }
  }
  return raw;
}

function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return req.socket?.remoteAddress || 'unknown';
}

function isValidEmail(value) {
  return typeof value === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value.trim());
}

function fail(res, status, code) {
  res.status(status).json({ error: code });
}

// Responses that must not reveal whether an account exists are held to a
// minimum duration, so the fast "no email sent" path is not trivially
// distinguishable from the slow "email sent" path by response time alone.
const MIN_NEUTRAL_RESPONSE_MS = 600;
const JITTER_MAX_MS = 150;

async function equalizeTiming(startedAt) {
  const floor = MIN_NEUTRAL_RESPONSE_MS + Math.floor(Math.random() * JITTER_MAX_MS);
  const elapsed = Date.now() - startedAt;
  if (elapsed < floor) {
    await new Promise((resolve) => setTimeout(resolve, floor - elapsed));
  }
}

module.exports = {
  guard,
  readBody,
  clientIp,
  isValidEmail,
  fail,
  equalizeTiming,
  MIN_NEUTRAL_RESPONSE_MS,
};
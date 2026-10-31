// Voice-note transcription proxy.
//
// Accepts the recording as base64 JSON (so no multipart parsing dependency is
// needed on the server), then rebuilds a multipart request for the provider.

const { readBody, clientIp } = require('../_lib/http');
const { guard, failAi } = require('../_lib/aiHttp');
const { requireUid } = require('../_lib/aiAuth');
const { consume } = require('../_lib/aiRateLimit');
const { validateTranscribeBody } = require('../_lib/aiValidate');
const { groqKey, callTranscribe } = require('../_lib/aiGroq');

module.exports = async (req, res) => {
  if (guard(req, res)) return;

  const auth = await requireUid(req);
  if (!auth.ok) {
    return failAi(res, auth.status, auth.code);
  }

  const validated = validateTranscribeBody(readBody(req));
  if (!validated.ok) {
    return failAi(res, 400, validated.code);
  }

  const limit = await consume({ uid: auth.uid, ip: clientIp(req) });
  if (!limit.ok) {
    return failAi(res, 429, 'rate_limited', limit.retryAfterSeconds);
  }

  const key = groqKey();
  if (!key) {
    return failAi(res, 500, 'ai_not_configured');
  }

  try {
    const upstream = await callTranscribe(validated.value, key);
    return res.status(upstream.status).json(upstream.json);
  } catch (error) {
    console.error('[ai/transcribe] upstream call failed:', error && error.name);
    return failAi(res, 502, 'upstream_unavailable');
  }
};

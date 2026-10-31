// SoleMate text chat and image turns, plus the Foot Photo assessment.
//
// The client no longer talks to Groq directly and no longer holds a provider
// key. This endpoint authenticates the caller with a Firebase ID token,
// applies abuse controls, validates and clamps the payload, and only then
// forwards the request upstream. Upstream status codes and bodies are passed
// through so the client's existing error mapping keeps working.

const { readBody, clientIp } = require('../_lib/http');
const { guard, failAi } = require('../_lib/aiHttp');
const { requireUid } = require('../_lib/aiAuth');
const { consume } = require('../_lib/aiRateLimit');
const { validateChatBody } = require('../_lib/aiValidate');
const { groqKey, callChat } = require('../_lib/aiGroq');

module.exports = async (req, res) => {
  if (guard(req, res)) return;

  const auth = await requireUid(req);
  if (!auth.ok) {
    return failAi(res, auth.status, auth.code);
  }

  const validated = validateChatBody(readBody(req));
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
    const upstream = await callChat(validated.value, key);
    // Never surface anything beyond the provider's own status and body.
    return res.status(upstream.status).json(upstream.json);
  } catch (error) {
    // Only the error name/message is logged. The key is in a request header,
    // which is never part of a thrown fetch error.
    console.error('[ai/chat] upstream call failed:', error && error.name);
    return failAi(res, 502, 'upstream_unavailable');
  }
};

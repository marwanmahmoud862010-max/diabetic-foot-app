// Authentication for the AI proxy endpoints.
//
// Reuses the existing firebase-admin helper so the new endpoints share one
// credential source with the rest of the API. The OTP implementation is not
// modified: this module only reads from firebase-admin, never writes.

const { auth } = require('./firebase-admin');

const BEARER_PATTERN = /^Bearer[ \t]+(\S+)$/i;

/**
 * Verifies the Firebase ID token sent as `Authorization: Bearer <token>`.
 *
 * Returns `{ ok: true, uid }` or `{ ok: false, status, code }`. The token
 * value is never logged, echoed back, or included in any error payload.
 */
async function requireUid(req) {
  const header = req.headers.authorization || req.headers.Authorization;
  if (typeof header !== 'string' || header.length === 0) {
    return { ok: false, status: 401, code: 'unauthorized' };
  }
  const match = header.match(BEARER_PATTERN);
  if (!match) {
    return { ok: false, status: 401, code: 'unauthorized' };
  }

  let verifier;
  try {
    verifier = auth();
  } catch (_) {
    // Admin credentials are not configured. This is a server fault, not a
    // client fault, so it is reported as such without leaking detail.
    return { ok: false, status: 500, code: 'server_error' };
  }

  try {
    const decoded = await verifier.verifyIdToken(match[1]);
    if (!decoded || typeof decoded.uid !== 'string' || decoded.uid.length === 0) {
      return { ok: false, status: 401, code: 'unauthorized' };
    }
    return { ok: true, uid: decoded.uid };
  } catch (_) {
    // Expired, malformed, forged, or wrong-project token. The cause is
    // deliberately not surfaced to the caller.
    return { ok: false, status: 401, code: 'unauthorized' };
  }
}

module.exports = { requireUid };

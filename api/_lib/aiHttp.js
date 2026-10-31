// Shared plumbing for the AI proxy endpoints.
//
// Kept separate from `_lib/http.js` so the OTP endpoints keep their exact
// existing response shape and CORS behaviour.

const ALLOWED_METHODS = ['POST', 'OPTIONS'];

// Browser clients are not expected (this backs a native app), but the headers
// are set correctly anyway: Authorization is allowed because the app sends a
// Firebase ID token.
function applyCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', ALLOWED_METHODS.join(', '));
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
}

/** Returns true when the request has already been answered. */
function guard(req, res) {
  applyCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return true;
  }
  if (req.method !== 'POST') {
    failAi(res, 405, 'method_not_allowed');
    return true;
  }
  return false;
}

const MESSAGES = {
  method_not_allowed: 'Only POST is supported.',
  unauthorized: 'A signed-in account is required.',
  rate_limited: 'Too many requests. Please try again shortly.',
  ai_not_configured: 'The AI service is not configured on the server.',
  upstream_unavailable: 'The AI service is temporarily unavailable.',
  server_error: 'An unexpected server error occurred.',
  invalid_body: 'Malformed request body.',
  invalid_messages: 'The conversation payload is invalid.',
  invalid_role: 'Unsupported message role.',
  invalid_content: 'Unsupported message content.',
  unsupported_content_type: 'Only text and image content are supported.',
  invalid_image: 'The attached image could not be read.',
  image_too_large: 'The attached image is too large.',
  too_many_images: 'Too many images in one request.',
  too_many_messages: 'Too many messages in one request.',
  content_too_large: 'The request payload is too large.',
  model_not_allowed: 'That model is not available.',
  invalid_temperature: 'Invalid temperature value.',
  invalid_top_p: 'Invalid top_p value.',
  invalid_max_tokens: 'Invalid max_tokens value.',
  invalid_file_name: 'Invalid file name.',
  unsupported_media_type: 'Unsupported audio type.',
  invalid_audio: 'The recorded audio could not be read.',
  audio_too_large: 'The recorded audio is too large.',
};

function messageFor(code) {
  return MESSAGES[code] || 'Request failed.';
}

/**
 * Error response shape understood by the Flutter client:
 * `{ error: { message, code } }`.
 */
function failAi(res, status, code, retryAfterSeconds) {
  if (typeof retryAfterSeconds === 'number' && retryAfterSeconds > 0) {
    res.setHeader('Retry-After', String(retryAfterSeconds));
  }
  res.status(status).json({ error: { message: messageFor(code), code } });
}

module.exports = { guard, failAi, messageFor };

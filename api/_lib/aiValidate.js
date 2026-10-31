// Pure request validation for the AI proxy endpoints.
//
// Deliberately dependency-free (no firebase-admin import) so it can be
// exercised directly with plain Node.

const ALLOWED_MODELS = Object.freeze([
  'openai/gpt-oss-120b',
  'qwen/qwen3.8-27b',
]);
const DEFAULT_TEXT_MODEL = 'openai/gpt-oss-120b';
const DEFAULT_VISION_MODEL = 'qwen/qwen3.8-27b';

const ALLOWED_ROLES = Object.freeze(['system', 'user', 'assistant']);

const MAX_MESSAGES = 40;
const MAX_TEXT_PART_CHARS = 30000;
const MAX_TOTAL_TEXT_CHARS = 120000;
const MAX_IMAGES = 3;
const MAX_IMAGE_DATA_URL_CHARS = 3800000;
const MAX_TOTAL_CONTENT_CHARS = 4200000;
const MAX_OUTPUT_TOKENS = 4096;

const ALLOWED_TRANSCRIBE_MODELS = Object.freeze([
  'whisper-large-v3-turbo',
  'whisper-large-v3',
]);
const DEFAULT_TRANSCRIBE_MODEL = 'whisper-large-v3-turbo';

const ALLOWED_AUDIO_TYPES = Object.freeze([
  'audio/mp4',
  'audio/mpeg',
  'audio/wav',
  'audio/x-wav',
  'audio/ogg',
  'audio/webm',
  'audio/flac',
  'audio/aac',
  'video/mp4',
]);
const MAX_FILE_NAME_CHARS = 128;
const MAX_AUDIO_BASE64_CHARS = 4000000;
const MAX_AUDIO_BYTES = 3000000;

const IMAGE_DATA_URL_PATTERN = /^data:image\/(?:jpeg|jpg|png|webp|gif);base64$/;
const BASE64_PATTERN = /^[A-Za-z0-9+/]+={0,2}$/;

const ok = (value) => ({ ok: true, value });
const bad = (code) => ({ ok: false, code });

function isBase64(value) {
  return (
    typeof value === 'string' &&
    value.length > 0 &&
    value.length % 4 === 0 &&
    BASE64_PATTERN.test(value)
  );
}

function parseImageDataUrl(url) {
  const comma = url.indexOf(',');
  if (comma < 0) return false;
  const meta = url.slice(0, comma);
  if (!IMAGE_DATA_URL_PATTERN.test(meta)) return false;
  const payload = url.slice(comma + 1).replace(/\s+/g, '');
  if (payload.length === 0) return false;
  return isBase64(payload);
}

function validateMessageContent(content, counters) {
  if (typeof content === 'string') {
    if (content.length === 0 || content.length > MAX_TEXT_PART_CHARS) {
      return { ok: false, code: 'invalid_content' };
    }
    counters.text += content.length;
    counters.total += content.length;
    return ok(content);
  }

  if (!Array.isArray(content) || content.length === 0) {
    return bad('invalid_content');
  }

  const parts = [];
  for (const part of content) {
    if (!part || typeof part !== 'object' || Array.isArray(part)) {
      return bad('invalid_content');
    }

    if (part.type === 'text') {
      const text = part.text;
      if (typeof text !== 'string' || text.length === 0 || text.length > MAX_TEXT_PART_CHARS) {
        return bad('invalid_content');
      }
      counters.text += text.length;
      counters.total += text.length;
      parts.push({ type: 'text', text });
      continue;
    }

    if (part.type === 'image_url') {
      const url = part.image_url && part.image_url.url;
      if (typeof url !== 'string' || !url.startsWith('data:image/')) {
        return bad('invalid_image');
      }
      if (url.length > MAX_IMAGE_DATA_URL_CHARS) {
        return bad('image_too_large');
      }
      if (!parseImageDataUrl(url)) {
        return bad('invalid_image');
      }
      counters.images += 1;
      counters.total += url.length;
      if (counters.images > MAX_IMAGES) {
        return bad('too_many_images');
      }
      parts.push({ type: 'image_url', image_url: { url } });
      continue;
    }

    // Anything else (notably inline audio) is rejected on purpose: these
    // endpoints only carry text and images.
    return bad('unsupported_content_type');
  }

  return ok(parts);
}

/**
 * Validates and normalises a chat proxy request.
 *
 * The caller cannot select an arbitrary upstream model: only the account's two
 * verified models are accepted, and sampling parameters are clamped.
 */
function validateChatBody(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return bad('invalid_body');
  }

  const messages = raw.messages;
  if (!Array.isArray(messages) || messages.length === 0) {
    return bad('invalid_messages');
  }
  if (messages.length > MAX_MESSAGES) {
    return bad('too_many_messages');
  }

  const counters = { text: 0, images: 0, total: 0 };
  const out = [];

  for (const message of messages) {
    if (!message || typeof message !== 'object' || Array.isArray(message)) {
      return bad('invalid_messages');
    }
    if (!ALLOWED_ROLES.includes(message.role)) {
      return bad('invalid_role');
    }
    const content = validateMessageContent(message.content, counters);
    if (!content.ok) return content;
    out.push({ role: message.role, content: content.value });
    if (counters.text > MAX_TOTAL_TEXT_CHARS || counters.total > MAX_TOTAL_CONTENT_CHARS) {
      return bad('content_too_large');
    }
  }

  let model = DEFAULT_TEXT_MODEL;
  if (raw.model !== undefined) {
    if (typeof raw.model !== 'string' || !ALLOWED_MODELS.includes(raw.model)) {
      return bad('model_not_allowed');
    }
    model = raw.model;
  } else if (counters.images > 0) {
    model = DEFAULT_VISION_MODEL;
  }

  let temperature = 0.5;
  if (raw.temperature !== undefined) {
    if (typeof raw.temperature !== 'number' || !Number.isFinite(raw.temperature) || raw.temperature < 0 || raw.temperature > 2) {
      return bad('invalid_temperature');
    }
    temperature = Math.min(raw.temperature, 1);
  }

  let topP = 0.9;
  if (raw.top_p !== undefined) {
    if (typeof raw.top_p !== 'number' || !Number.isFinite(raw.top_p) || raw.top_p <= 0 || raw.top_p > 1) {
      return bad('invalid_top_p');
    }
    topP = raw.top_p;
  }

  let maxTokens = 2048;
  if (raw.max_tokens !== undefined) {
    if (!Number.isInteger(raw.max_tokens) || raw.max_tokens < 1 || raw.max_tokens > MAX_OUTPUT_TOKENS) {
      return bad('invalid_max_tokens');
    }
    maxTokens = raw.max_tokens;
  }

  return ok({
    model,
    messages: out,
    temperature,
    top_p: topP,
    max_tokens: maxTokens,
  });
}

/** Validates a base64 voice-note transcription request. */
function validateTranscribeBody(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return bad('invalid_body');
  }

  const fileName = typeof raw.fileName === 'string' ? raw.fileName.trim() : '';
  if (fileName.length === 0 || fileName.length > MAX_FILE_NAME_CHARS) {
    return bad('invalid_file_name');
  }

  const mimeType = typeof raw.mimeType === 'string' ? raw.mimeType.trim().toLowerCase() : '';
  if (!ALLOWED_AUDIO_TYPES.includes(mimeType)) {
    return bad('unsupported_media_type');
  }

  const audioBase64 = typeof raw.audioBase64 === 'string' ? raw.audioBase64 : '';
  if (audioBase64.length === 0) {
    return bad('invalid_audio');
  }
  if (audioBase64.length > MAX_AUDIO_BASE64_CHARS) {
    return bad('audio_too_large');
  }
  if (!isBase64(audioBase64)) {
    return bad('invalid_audio');
  }

  const buffer = Buffer.from(audioBase64, 'base64');
  if (buffer.length === 0 || buffer.length > MAX_AUDIO_BYTES) {
    return bad('audio_too_large');
  }

  let model = DEFAULT_TRANSCRIBE_MODEL;
  if (raw.model !== undefined) {
    if (typeof raw.model !== 'string' || !ALLOWED_TRANSCRIBE_MODELS.includes(raw.model)) {
      return bad('model_not_allowed');
    }
    model = raw.model;
  }

  return ok({ fileName, mimeType, buffer, model });
}

module.exports = {
  ALLOWED_MODELS,
  ALLOWED_AUDIO_TYPES,
  ALLOWED_TRANSCRIBE_MODELS,
  DEFAULT_TEXT_MODEL,
  DEFAULT_VISION_MODEL,
  DEFAULT_TRANSCRIBE_MODEL,
  MAX_IMAGES,
  MAX_OUTPUT_TOKENS,
  MAX_AUDIO_BYTES,
  validateChatBody,
  validateTranscribeBody,
};

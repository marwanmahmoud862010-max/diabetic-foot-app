// Server-to-server calls to Groq.
//
// The API key is read from the Vercel environment only. It is attached to the
// outbound Authorization header and is never logged, returned, or embedded in
// any response or error message.

const crypto = require('crypto');

const GROQ_BASE = 'https://api.groq.com/openai/v1';
const UPSTREAM_TIMEOUT_MS = 25000;

const PLACEHOLDERS = new Set(['', 'YOUR_GROQ_API_KEY']);

/**
 * Reads the Groq credential from the environment.
 *
 * Returns `null` when it is absent or still a placeholder, so callers can
 * report a clean configuration error instead of attempting an unauthenticated
 * upstream call.
 */
function groqKey() {
  const raw = process.env.GROQ_API_KEY;
  const key = typeof raw === 'string' ? raw.trim() : '';
  return PLACEHOLDERS.has(key) ? null : key;
}

async function withTimeout(run) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
  try {
    return await run(controller.signal);
  } finally {
    clearTimeout(timer);
  }
}

async function readJson(response) {
  const text = await response.text();
  try {
    return JSON.parse(text);
  } catch (_) {
    return { error: { message: 'upstream returned a non-JSON response' } };
  }
}

/** Forwards a chat completion request. Status and body pass through unchanged. */
async function callChat(payload, key) {
  return withTimeout(async (signal) => {
    const response = await fetch(`${GROQ_BASE}/chat/completions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal,
    });
    return { status: response.status, json: await readJson(response) };
  });
}

function sanitizeFileName(name) {
  const cleaned = String(name).replace(/[^A-Za-z0-9._-]/g, '_').slice(0, 64);
  return cleaned.length > 0 ? cleaned : 'audio';
}

/**
 * Builds a multipart/form-data body by hand.
 *
 * Done locally so no extra runtime dependency is needed for the proxy.
 */
function buildMultipart({ fields, fileField, fileName, contentType, fileBuffer }) {
  const boundary = `----StepGuardAI${crypto.randomBytes(12).toString('hex')}`;
  const chunks = [];

  for (const [name, value] of Object.entries(fields)) {
    chunks.push(
      Buffer.from(
        `--${boundary}\r\n` +
          `Content-Disposition: form-data; name="${name}"\r\n\r\n` +
          `${value}\r\n`,
      ),
    );
  }

  chunks.push(
    Buffer.from(
      `--${boundary}\r\n` +
        `Content-Disposition: form-data; name="${fileField}"; filename="${sanitizeFileName(fileName)}"\r\n` +
        `Content-Type: ${contentType}\r\n\r\n`,
    ),
  );
  chunks.push(fileBuffer);
  chunks.push(Buffer.from(`\r\n--${boundary}--\r\n`));

  return { boundary, body: Buffer.concat(chunks) };
}

/** Forwards a speech-to-text request. Status and body pass through unchanged. */
async function callTranscribe({ model, fileName, mimeType, buffer }, key) {
  return withTimeout(async (signal) => {
    const { boundary, body } = buildMultipart({
      fields: { model },
      fileField: 'file',
      fileName,
      contentType: mimeType,
      fileBuffer: buffer,
    });

    const response = await fetch(`${GROQ_BASE}/audio/transcriptions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${key}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
      },
      body,
      signal,
    });
    return { status: response.status, json: await readJson(response) };
  });
}

module.exports = { groqKey, callChat, callTranscribe, sanitizeFileName, buildMultipart };

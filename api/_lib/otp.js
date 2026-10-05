const crypto = require('crypto');

const OTP_LENGTH = 6;
const OTP_MIN = 100000;
const OTP_MAX = 1000000;
const OTP_TTL_MINUTES = 10;
const MAX_VERIFY_ATTEMPTS = 5;
const RESET_TOKEN_TTL_MINUTES = 15;

const RESEND_COOLDOWN_SECONDS = 60;
const IP_HOURLY_LIMIT = 10;
const EMAIL_HOURLY_LIMIT = 5;

function otpSecret() {
  const secret = process.env.OTP_HMAC_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error('OTP_HMAC_SECRET is missing or too short (min 32 chars)');
  }
  return secret;
}

function generateOtp() {
  return String(crypto.randomInt(OTP_MIN, OTP_MAX)).padStart(OTP_LENGTH, '0');
}

function generateResetToken() {
  return crypto.randomBytes(32).toString('hex');
}

function normalizeEmail(email) {
  return String(email).trim().toLowerCase();
}

function otpHash(email, code) {
  return crypto
    .createHmac('sha256', otpSecret())
    .update(`${normalizeEmail(email)}:${code}`)
    .digest('hex');
}

function resetTokenHash(email, token) {
  return crypto
    .createHmac('sha256', otpSecret())
    .update(`reset:${normalizeEmail(email)}:${token}`)
    .digest('hex');
}

function hashKey(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function timingSafeEqualHex(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) {
    return false;
  }
  try {
    return crypto.timingSafeEqual(Buffer.from(a, 'hex'), Buffer.from(b, 'hex'));
  } catch (_) {
    return false;
  }
}

module.exports = {
  OTP_LENGTH,
  OTP_TTL_MINUTES,
  MAX_VERIFY_ATTEMPTS,
  RESET_TOKEN_TTL_MINUTES,
  RESEND_COOLDOWN_SECONDS,
  IP_HOURLY_LIMIT,
  EMAIL_HOURLY_LIMIT,
  generateOtp,
  generateResetToken,
  normalizeEmail,
  otpHash,
  resetTokenHash,
  hashKey,
  timingSafeEqualHex,
};
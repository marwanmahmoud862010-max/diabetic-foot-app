const {
  OTP_TTL_MINUTES,
  MAX_VERIFY_ATTEMPTS,
  RESET_TOKEN_TTL_MINUTES,
  RESEND_COOLDOWN_SECONDS,
  IP_HOURLY_LIMIT,
  EMAIL_HOURLY_LIMIT,
  generateResetToken,
  resetTokenHash,
  hashKey,
  timingSafeEqualHex,
} = require('./otp');
const { firestore } = require('./firebase-admin');

const OTP_COLLECTION = 'passwordResetOtps';
const RATE_COLLECTION = 'passwordResetRate';
const HOUR_MS = 60 * 60 * 1000;
const MAX_TRACKED_ENTRIES = 64;

function db() {
  return firestore();
}

function nowMs() {
  return Date.now();
}

async function saveOtp({ emailKey, email, uid, codeHash }) {
  const ref = db().collection(OTP_COLLECTION).doc(emailKey);
  const existing = await ref.get();
  const previousAttempts = existing.exists ? (existing.get('verifyAttempts') || 0) : 0;

  await ref.set(
    {
      email,
      uid,
      codeHash,
      verifyAttempts: previousAttempts,
      createdAt: Date.now(),
      expiresAt: Date.now() + OTP_TTL_MINUTES * 60 * 1000,
      verifiedAt: null,
      resetTokenHash: null,
      resetTokenExpiresAt: 0,
      resetTokenConsumed: false,
    },
    { merge: true },
  );
}

async function getOtpRecord(emailKey) {
  const snap = await db().collection(OTP_COLLECTION).doc(emailKey).get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  return { ref: snap.ref, ...data };
}

async function incrementVerifyAttempts(record) {
  const attempts = (record.verifyAttempts || 0) + 1;
  await record.ref.set({ verifyAttempts: attempts }, { merge: true });
  return attempts;
}

async function clearOtp(emailKey) {
  await db().collection(OTP_COLLECTION).doc(emailKey).delete();
}

async function issueResetToken(record, emailKey) {
  const token = generateResetToken();
  const tokenHash = resetTokenHash(record.email, token);
  const expiresAt = Date.now() + RESET_TOKEN_TTL_MINUTES * 60 * 1000;
  const ref = record.ref || db().collection(OTP_COLLECTION).doc(emailKey);

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() || {} : {};
    if (data.verifiedAt) {
      const err = new Error('otp_already_verified');
      err.code = 'otp_already_verified';
      throw err;
    }
    tx.update(ref, {
      verifiedAt: Date.now(),
      codeHash: null,
      resetTokenHash: tokenHash,
      resetTokenExpiresAt: expiresAt,
      resetTokenConsumed: false,
    });
  });

  return token;
}

async function claimResetToken(record, token, emailKey) {
  const ref = record.ref || db().collection(OTP_COLLECTION).doc(emailKey);
  let claimed = null;

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const data = snap.data() || {};
    if (data.resetTokenConsumed) return;
    if (!resetTokenValid({ ...data, ref }, token)) return;
    tx.update(ref, { resetTokenConsumed: true, resetTokenConsumedAt: Date.now() });
    claimed = data;
  });

  return claimed;
}

async function releaseResetTokenClaim(record) {
  const ref = record && record.ref;
  if (!ref) return;
  await ref.update({ resetTokenConsumed: false });
}

async function checkHourlyLimits(ipKey, emailKey) {
  const windowStart = nowMs() - HOUR_MS;
  const ipCount = await countRecent(`ip:${ipKey}`, windowStart);
  if (ipCount >= IP_HOURLY_LIMIT) return { ok: false };

  const emailCount = await countRecent(`email:${emailKey}`, windowStart);
  if (emailCount >= EMAIL_HOURLY_LIMIT) return { ok: false };

  return { ok: true };
}

async function countRecent(docId, since) {
  const snap = await db().collection(RATE_COLLECTION).doc(docId).get();
  if (!snap.exists) return 0;
  const data = snap.data() || {};
  const entries = Array.isArray(data.entries) ? data.entries : [];
  return entries.filter((ts) => typeof ts === 'number' && ts > since).length;
}

async function recordAttemptOnly(ipKey, emailKey) {
  await appendEntry(`ip:${ipKey}`);
  await appendEntry(`email:${emailKey}`);
}

async function appendEntry(docId) {
  const ref = db().collection(RATE_COLLECTION).doc(docId);
  const cutoff = nowMs() - HOUR_MS;

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() || {} : {};
    const existing = Array.isArray(data.entries) ? data.entries : [];
    const kept = existing.filter((ts) => typeof ts === 'number' && ts > cutoff);
    kept.push(Date.now());
    tx.set(ref, { entries: kept.slice(-MAX_TRACKED_ENTRIES) }, { merge: true });
  });
}

async function checkCooldown(emailKey) {
  const record = await getOtpRecord(emailKey);
  if (!record || !record.createdAt) return { ok: true };
  const elapsed = nowMs() - record.createdAt;
  if (elapsed < RESEND_COOLDOWN_SECONDS * 1000) {
    return { ok: false, retryAfter: Math.ceil((RESEND_COOLDOWN_SECONDS * 1000 - elapsed) / 1000) };
  }
  return { ok: true };
}

function isExpired(record) {
  return !record || !record.expiresAt || record.expiresAt < nowMs();
}

function resetTokenValid(record, token) {
  if (!record || !record.resetTokenHash || !record.resetTokenExpiresAt) return false;
  if (record.resetTokenConsumed) return false;
  if (record.resetTokenExpiresAt < nowMs()) return false;
  return timingSafeEqualHex(record.resetTokenHash, resetTokenHash(record.email, token));
}

module.exports = {
  saveOtp,
  getOtpRecord,
  incrementVerifyAttempts,
  clearOtp,
  issueResetToken,
  claimResetToken,
  releaseResetTokenClaim,
  checkHourlyLimits,
  recordAttemptOnly,
  checkCooldown,
  isExpired,
  resetTokenValid,
  MAX_VERIFY_ATTEMPTS,
  hashKey,
};
const { guard, readBody, isValidEmail, fail } = require('./_lib/http');
const { normalizeEmail, otpHash, hashKey, timingSafeEqualHex, MAX_VERIFY_ATTEMPTS } = require('./_lib/otp');
const store = require('./_lib/store');

module.exports = async (req, res) => {
  if (guard(req, res)) return;

  const { email, otp } = readBody(req);
  if (!isValidEmail(email)) {
    return fail(res, 400, 'invalid_email');
  }
  if (typeof otp !== 'string' || !/^\d{6}$/.test(otp.trim())) {
    return fail(res, 400, 'invalid_otp_format');
  }

  const normalized = normalizeEmail(email);
  const emailKey = hashKey(normalized);

  try {
    const record = await store.getOtpRecord(emailKey);
    if (!record) {
      return fail(res, 400, 'otp_not_requested');
    }
    if (store.isExpired(record)) {
      await store.clearOtp(emailKey);
      return fail(res, 400, 'otp_expired');
    }
    if (record.verifyAttempts >= MAX_VERIFY_ATTEMPTS) {
      await store.clearOtp(emailKey);
      return fail(res, 429, 'too_many_attempts');
    }
    if (record.verifiedAt || !record.codeHash) {
      // Already consumed. Do not delete: a valid reset token may still be in flight.
      return fail(res, 400, 'otp_already_verified');
    }

    const matches = timingSafeEqualHex(record.codeHash, otpHash(normalized, otp.trim()));

    if (!matches) {
      const attempts = await store.incrementVerifyAttempts(record);
      if (attempts >= MAX_VERIFY_ATTEMPTS) {
        await store.clearOtp(emailKey);
        return fail(res, 429, 'too_many_attempts');
      }
      return fail(res, 400, 'otp_incorrect');
    }

    let resetToken;
    try {
      resetToken = await store.issueResetToken(record, emailKey);
    } catch (error) {
      if (error && error.code === 'otp_already_verified') {
        return fail(res, 400, 'otp_already_verified');
      }
      throw error;
    }
    return res.status(200).json({ success: true, resetToken });
  } catch (error) {
    console.error('[verify-otp] failed:', error.message);
    return fail(res, 500, 'server_error');
  }
};
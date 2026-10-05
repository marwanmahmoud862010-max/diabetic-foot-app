const { guard, readBody, isValidEmail, fail } = require('./_lib/http');
const { normalizeEmail, hashKey } = require('./_lib/otp');
const store = require('./_lib/store');
const { updateUserPassword } = require('./_lib/firebase-admin');

const MIN_PASSWORD_LENGTH = 8;

module.exports = async (req, res) => {
  if (guard(req, res)) return;

  const { email, password, resetToken } = readBody(req);
  if (!isValidEmail(email)) {
    return fail(res, 400, 'invalid_email');
  }
  if (typeof password !== 'string' || password.length < MIN_PASSWORD_LENGTH) {
    return fail(res, 400, 'weak_password');
  }
  if (typeof resetToken !== 'string' || resetToken.length < 32) {
    return fail(res, 400, 'invalid_reset_token');
  }

  const normalized = normalizeEmail(email);
  const emailKey = hashKey(normalized);

  try {
    const record = await store.getOtpRecord(emailKey);
    if (!record || !record.uid) {
      return fail(res, 400, 'otp_not_requested');
    }
    if (!store.resetTokenValid(record, resetToken)) {
      return fail(res, 400, 'invalid_reset_token');
    }

    const claimed = await store.claimResetToken(record, resetToken, emailKey);
    if (!claimed) {
      return fail(res, 400, 'invalid_reset_token');
    }

    try {
      await updateUserPassword(claimed.uid, password);
    } catch (error) {
      const code = error && error.code;
      if (code === 'auth/invalid-password') {
        return fail(res, 400, 'weak_password');
      }
      if (code === 'auth/user-not-found') {
        await store.clearOtp(emailKey);
        return fail(res, 400, 'user_not_found');
      }
      // Transient failure: hand the token back so the user can retry.
      await store.releaseResetTokenClaim(record);
      throw error;
    }

    await store.clearOtp(emailKey);

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('[confirm-reset] failed:', error.message);
    return fail(res, 500, 'server_error');
  }
};
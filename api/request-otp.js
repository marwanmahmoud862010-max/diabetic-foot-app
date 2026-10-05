const { guard, readBody, clientIp, isValidEmail, fail, equalizeTiming } = require('./_lib/http');
const { normalizeEmail, generateOtp, otpHash, hashKey } = require('./_lib/otp');
const store = require('./_lib/store');
const { sendOtpEmail } = require('./_lib/mailer');
const { getUserByEmail } = require('./_lib/firebase-admin');

const startedAt = Date.now();

module.exports = async (req, res) => {
  if (guard(req, res)) return;

  const { email } = readBody(req);
  if (!isValidEmail(email)) {
    return fail(res, 400, 'invalid_email');
  }

  const normalized = normalizeEmail(email);
  const ip = clientIp(req);
  const emailKey = hashKey(normalized);
  const ipKey = hashKey(ip);

  try {
    const hourly = await store.checkHourlyLimits(ipKey, emailKey);
    if (!hourly.ok) {
      return fail(res, 429, 'too_many_requests');
    }

    const cooldown = await store.checkCooldown(emailKey);
    if (!cooldown.ok) {
      return res.status(200).json({ success: true, cooldown: true });
    }

    const user = await getUserByEmail(normalized);

    // Unknown and known emails must be indistinguishable from the outside, so
    // both get a stored code hash. Only a real account has a uid and an email
    // sent to it, and neither fact is observable in the response.
    const code = generateOtp();
    await store.saveOtp({
      emailKey,
      email: normalized,
      uid: user ? user.uid : null,
      codeHash: otpHash(normalized, code),
    });
    await store.recordAttemptOnly(ipKey, emailKey);

    if (user) {
      try {
        await sendOtpEmail(normalized, code);
      } catch (mailError) {
        // Drop the code so a retry is possible, but answer exactly as if it had
        // been sent. A distinct status here would re-introduce enumeration.
        await store.clearOtp(emailKey);
        console.error('[request-otp] mail send failed:', mailError.message);
        await equalizeTiming(startedAt);
        return res.status(200).json({ success: true, cooldown: false });
      }
    }

    await equalizeTiming(startedAt);
    return res.status(200).json({ success: true, cooldown: false });
  } catch (error) {
    console.error('[request-otp] failed:', error.message);
    return fail(res, 500, 'server_error');
  }
};
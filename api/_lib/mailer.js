const BREVO_ENDPOINT = 'https://api.brevo.com/v3/smtp/email';
const MAX_ATTEMPTS = 3;
const RETRY_DELAYS_MS = [1000, 2000];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => {
    switch (char) {
      case '&':
        return '&amp;';
      case '<':
        return '&lt;';
      case '>':
        return '&gt;';
      case '"':
        return '&quot;';
      default:
        return '&#39;';
    }
  });
}

function buildHtml(code) {
  const spaced = escapeHtml(code).split('').join('</span><span style="font-size:38px;font-weight:700;letter-spacing:8px;color:#00695C;">');
  return `<!DOCTYPE html>
<html><body style="margin:0;padding:0;background-color:#f4f6f5;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f6f5;padding:40px 20px;">
<tr><td align="center">
<table width="480" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);">
<tr><td style="background-color:#00695C;padding:32px;text-align:center;">
<h1 style="color:#ffffff;margin:0;font-size:24px;">StepGuard</h1>
<p style="color:#b2dfdb;margin:8px 0 0 0;font-size:14px;">Diabetic Foot Care</p>
</td></tr>
<tr><td style="padding:32px 24px;text-align:center;">
<h2 style="color:#263238;margin:0 0 16px 0;font-size:20px;">Password Reset Code</h2>
<p style="color:#607d8b;margin:0 0 24px 0;font-size:14px;">Use this code to reset your password:</p>
<div style="background-color:#e0f2f1;border:2px dashed #00695C;border-radius:8px;padding:16px;margin:0 auto 24px auto;max-width:260px;">
<span style="font-size:38px;font-weight:700;letter-spacing:8px;color:#00695C;">${spaced}</span>
</div>
<p style="color:#90a4ae;margin:0;font-size:12px;">This code expires in 10 minutes. If you did not request it, you can ignore this email.</p>
</td></tr>
<tr><td style="background-color:#fafafa;padding:16px 24px;text-align:center;border-top:1px solid #eeeeee;">
<p style="color:#b0bec5;margin:0;font-size:11px;">StepGuard &bull; Diabetic Foot Care</p>
</td></tr>
</table>
</td></tr></table>
</body></html>`;
}

async function sendOtpEmail(email, code) {
  const apiKey = process.env.BREVO_API_KEY;
  const senderEmail = process.env.BREVO_SENDER_EMAIL;
  const senderName = process.env.BREVO_SENDER_NAME || 'StepGuard';

  if (!apiKey || !senderEmail) {
    throw new Error('BREVO_API_KEY or BREVO_SENDER_EMAIL is not configured');
  }

  const payload = {
    sender: { name: senderName, email: senderEmail },
    to: [{ email }],
    subject: `${senderName} password reset code`,
    htmlContent: buildHtml(code),
    tags: ['password-reset'],
  };

  let lastError = null;
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 15000);
      const response = await fetch(BREVO_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'api-key': apiKey },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      clearTimeout(timer);

      if (response.ok) {
        return true;
      }
      const detail = await response.text();
      lastError = new Error(`Brevo responded ${response.status}: ${detail}`);
      if (response.status >= 400 && response.status < 500 && response.status !== 429) {
        throw lastError;
      }
    } catch (error) {
      lastError = error;
      if (error.message && /^Brevo responded 4/.test(error.message)) throw error;
    }
    if (attempt < MAX_ATTEMPTS) await sleep(RETRY_DELAYS_MS[attempt - 1]);
  }
  throw lastError || new Error('Failed to send OTP email');
}

module.exports = { sendOtpEmail };
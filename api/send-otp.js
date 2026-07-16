const BREVO_API_KEY = process.env.BREVO_API_KEY;
const BREVO_SENDER_EMAIL = process.env.BREVO_SENDER_EMAIL || 'marwanmahmoud862010@gmail.com';
const MAX_RETRIES = 3;
const RETRY_DELAYS = [1000, 2000, 4000];

function buildHtml(otp) {
  const code = otp.split('').join('</span><span style="font-size:36px;font-weight:bold;letter-spacing:6px;color:#1565C0;">');
  return `<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background-color:#f4f4f4;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;padding:40px 20px;">
    <tr><td align="center">
      <table width="480" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);">
        <tr><td style="background:linear-gradient(135deg,#1565C0,#0D47A1);padding:32px;text-align:center;">
          <h1 style="color:#ffffff;margin:0;font-size:24px;">StepGuard</h1>
          <p style="color:#bbdefb;margin:8px 0 0 0;font-size:14px;">Diabetic Foot Care</p>
        </td></tr>
        <tr><td style="padding:32px 24px;text-align:center;">
          <h2 style="color:#333333;margin:0 0 16px 0;font-size:20px;">Password Reset OTP</h2>
          <p style="color:#666666;margin:0 0 24px 0;font-size:14px;">Your verification code is:</p>
          <div style="background-color:#f0f4ff;border:2px dashed #1565C0;border-radius:8px;padding:16px;margin:0 auto 24px auto;max-width:260px;">
            <span style="font-size:36px;font-weight:bold;letter-spacing:6px;color:#1565C0;">${code}</span>
          </div>
          <p style="color:#999999;margin:0;font-size:12px;">This code is valid for 15 minutes.</p>
        </td></tr>
        <tr><td style="background-color:#fafafa;padding:16px 24px;text-align:center;border-top:1px solid #eeeeee;">
          <p style="color:#aaaaaa;margin:0;font-size:11px;">StepGuard &bull; Diabetic Foot Care &bull; Protecting your steps</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

async function sendViaBrevo(email, otp, requestId) {
  const url = 'https://api.brevo.com/v3/smtp/email';
  const timestamp = Date.now();
  const subject = `Your OTP Code - StepGuard [${timestamp}]`;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 15000);

      const body = {
        sender: { name: 'StepGuard', email: BREVO_SENDER_EMAIL },
        to: [{ email }],
        subject,
        htmlContent: buildHtml(otp),
        headers: {
          'X-OTP-Request-ID': requestId,
          'X-OTP-Sent-At': new Date(timestamp).toISOString(),
        },
        tags: ['otp', 'password-reset'],
      };

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'api-key': BREVO_API_KEY,
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      clearTimeout(timeout);
      const data = await response.json();

      console.log(`[${requestId}] Brevo attempt ${attempt}/${MAX_RETRIES}: status=${response.status} body=${JSON.stringify(data)}`);

      if (response.status === 201 && data.messageId) {
        console.log(`[${requestId}] OTP queued successfully. messageId=${data.messageId}`);
        return { messageId: data.messageId, brevoStatusCode: response.status };
      }

      // 4xx errors (except 429 rate-limit) are non-retriable
      if (response.status >= 400 && response.status < 500 && response.status !== 429) {
        throw new Error(`Brevo (${response.status}): ${data.message || JSON.stringify(data)}`);
      }

      // 5xx or 429: retry
      console.log(`[${requestId}] Retriable error, retry ${attempt}/${MAX_RETRIES} in ${RETRY_DELAYS[attempt - 1]}ms`);
      await sleep(RETRY_DELAYS[attempt - 1]);
    } catch (err) {
      if (err.message && err.message.startsWith('Brevo (')) throw err;
      if (attempt < MAX_RETRIES) {
        console.log(`[${requestId}] Error, retry ${attempt}/${MAX_RETRIES} in ${RETRY_DELAYS[attempt - 1]}ms: ${err.message}`);
        await sleep(RETRY_DELAYS[attempt - 1]);
        continue;
      }
      throw new Error(`All ${MAX_RETRIES} attempts failed: ${err.message}`);
    }
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function generateRequestId() {
  const ts = Date.now().toString(36);
  const rnd = Math.random().toString(36).substring(2, 8);
  return `otp-${ts}-${rnd}`;
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { email, otp } = req.body || {};

  if (!email || typeof email !== 'string' || !email.includes('@')) {
    return res.status(400).json({ error: 'A valid email is required' });
  }

  if (!otp || typeof otp !== 'string' || otp.length !== 6) {
    return res.status(400).json({ error: 'A valid 6-digit OTP is required' });
  }

  if (!BREVO_API_KEY) {
    console.error('BREVO_API_KEY is not set');
    return res.status(500).json({ error: 'Server configuration error: BREVO_API_KEY missing' });
  }

  const requestId = generateRequestId();
  console.log(`[${requestId}] Starting OTP send to=${email}`);

  try {
    const result = await sendViaBrevo(email, otp, requestId);
    return res.status(200).json({ success: true, messageId: result.messageId, requestId });
  } catch (error) {
    console.error(`[${requestId}] send-otp failed: ${error.message}`);
    return res.status(200).json({
      success: false,
      error: error.message,
      requestId,
      _detail: 'Check Brevo dashboard at https://app.brevo.com for sender status and quota.',
    });
  }
};

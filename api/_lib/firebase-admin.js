let cachedApp = null;

const PEM_HEADER = '-----BEGIN PRIVATE KEY-----';
const PEM_FOOTER = '-----END PRIVATE KEY-----';

// Metadata-only. Never logs the key or any fragment of it.
function inspectPrivateKeyShape(raw) {
  if (typeof raw !== 'string' || raw.length === 0) {
    return { present: false };
  }
  const hasQuotes =
    raw.startsWith('"') || raw.endsWith('"') || raw.startsWith("'") || raw.endsWith("'");
  return {
    present: true,
    length: raw.length,
    startsWithHeader: raw.trim().startsWith(PEM_HEADER),
    endsWithFooter: raw.trim().endsWith(PEM_FOOTER),
    pemLineCount: raw.split(/\r\n|\r|\n/).filter((l) => l.length > 0).length,
    containsLiteralBackslashN: raw.includes('\\n'),
    hasSurroundingQuotes: hasQuotes,
    hasCarriageReturn: raw.includes('\r'),
    singleLine: !/[\r\n]/.test(raw),
  };
}

function getApp() {
  if (cachedApp) return cachedApp;

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKeyRaw = process.env.FIREBASE_PRIVATE_KEY;

  if (!projectId || !clientEmail || !privateKeyRaw) {
    throw new Error(
      'Missing Firebase Admin credentials: FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY',
    );
  }

  const shape = inspectPrivateKeyShape(privateKeyRaw);
  console.log('[firebase-admin] private key shape:', JSON.stringify(shape));

  const privateKey = privateKeyRaw.replace(/\\n/g, '\n');

  // Lazy require so a missing dependency only breaks calls that need Admin.
  const admin = require('firebase-admin');

  try {
    cachedApp = admin.apps[0]
      ? admin.app()
      : admin.initializeApp({
          credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
        });
  } catch (error) {
    console.error('[firebase-admin] initializeApp failed:', error.message);
    throw error;
  }

  return cachedApp;
}

function auth() {
  return getApp().auth();
}

function firestore() {
  return getApp().firestore();
}

async function getUserByEmail(email) {
  try {
    return await auth().getUserByEmail(email);
  } catch (error) {
    if (error && error.code === 'auth/user-not-found') return null;
    throw error;
  }
}

async function updateUserPassword(uid, password) {
  return auth().updateUser(uid, { password });
}

module.exports = {
  getApp,
  auth,
  firestore,
  getUserByEmail,
  updateUserPassword,
  inspectPrivateKeyShape,
};
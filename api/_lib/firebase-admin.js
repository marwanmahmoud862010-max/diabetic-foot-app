let cachedApp = null;

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

  const privateKey = privateKeyRaw.replace(/\\n/g, '\n');

  // Lazy require so a missing dependency only breaks calls that need Admin.
  const admin = require('firebase-admin');

  cachedApp = admin.apps[0]
    ? admin.app()
    : admin.initializeApp({
        credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
      });

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

module.exports = { getApp, auth, firestore, getUserByEmail, updateUserPassword };
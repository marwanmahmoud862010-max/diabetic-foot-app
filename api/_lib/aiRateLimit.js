// Rolling-window abuse controls for the AI proxy endpoints.
//
// Same storage approach as the OTP rate limiter (Firestore document per
// subject, timestamp entries, two cutoffs) but a separate collection, so the
// password-reset counters are never read, written, or reinterpreted here.

const { hashKey } = require('./otp');
const { firestore } = require('./firebase-admin');

const COLLECTION = 'aiProxyRate';
const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;
const MAX_TRACKED_ENTRIES = 128;

// Per-subject ceilings. The per-IP figures are looser than the per-UID ones
// because mobile carriers put many users behind one address.
const LIMITS = {
  uidPerMinute: 10,
  uidPerHour: 100,
  ipPerMinute: 20,
  ipPerHour: 150,
};

function db() {
  return firestore();
}

async function countSince(docId, since) {
  const snap = await db().collection(COLLECTION).doc(docId).get();
  if (!snap.exists) return { count: 0, oldest: null };
  const data = snap.data() || {};
  const entries = Array.isArray(data.entries) ? data.entries : [];
  const live = entries.filter((ts) => typeof ts === 'number' && ts > since);
  return {
    count: live.length,
    oldest: live.length > 0 ? Math.min(...live) : null,
  };
}

async function appendEntry(docId, cutoff) {
  const ref = db().collection(COLLECTION).doc(docId);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() || {} : {};
    const existing = Array.isArray(data.entries) ? data.entries : [];
    const kept = existing.filter((ts) => typeof ts === 'number' && ts > cutoff);
    kept.push(Date.now());
    tx.set(ref, { entries: kept.slice(-MAX_TRACKED_ENTRIES) }, { merge: true });
  });
}

function retryAfterFor(oldest, windowMs) {
  if (typeof oldest !== 'number') return Math.ceil(windowMs / 1000);
  const remaining = oldest + windowMs - Date.now();
  return Math.max(1, Math.ceil(remaining / 1000));
}

/**
 * Checks every window for the caller, then records the attempt.
 *
 * Returns `{ ok: true }` or `{ ok: false, retryAfterSeconds }`. The check runs
 * before any recording so rejected requests do not extend their own penalty.
 */
async function consume({ uid, ip }) {
  const now = Date.now();
  const uidDoc = `uid:${hashKey(uid)}`;
  const ipDoc = `ip:${hashKey(ip || 'unknown')}`;

  const checks = [
    { docId: uidDoc, since: now - MINUTE_MS, limit: LIMITS.uidPerMinute, window: MINUTE_MS },
    { docId: uidDoc, since: now - HOUR_MS, limit: LIMITS.uidPerHour, window: HOUR_MS },
    { docId: ipDoc, since: now - MINUTE_MS, limit: LIMITS.ipPerMinute, window: MINUTE_MS },
    { docId: ipDoc, since: now - HOUR_MS, limit: LIMITS.ipPerHour, window: HOUR_MS },
  ];

  for (const check of checks) {
    const { count, oldest } = await countSince(check.docId, check.since);
    if (count >= check.limit) {
      return { ok: false, retryAfterSeconds: retryAfterFor(oldest, check.window) };
    }
  }

  const cutoff = now - HOUR_MS;
  await appendEntry(uidDoc, cutoff);
  await appendEntry(ipDoc, cutoff);
  return { ok: true };
}

module.exports = { consume, LIMITS };

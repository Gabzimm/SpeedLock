// repositories/securityRepo.js
const db = require('./db');
const usersRepo = require('./usersRepo');
const { COLLECTIONS, FLAG_THRESHOLD } = require('../config/constants');

function logSuspiciousActivity(uid, deviceId, reason) {
  return db.collection(COLLECTIONS.SUSPICIOUS_ACTIVITY).add({
    uid,
    deviceId: deviceId || null,
    reason,
    timestamp: Date.now(),
  });
}

async function incrementSuspiciousCount(uid) {
  const snap = await usersRepo.getSecurityDoc(uid);
  const count = (snap.exists ? snap.data().suspiciousCount : 0) + 1;
  await usersRepo.setSecurityDoc(uid, {
    suspiciousCount: count,
    flagged: count >= FLAG_THRESHOLD,
    lastFlaggedAt: Date.now(),
  });
  return count;
}

async function isAccountFlagged(uid) {
  const snap = await usersRepo.getSecurityDoc(uid);
  return snap.exists && snap.data().flagged === true;
}

module.exports = { logSuspiciousActivity, incrementSuspiciousCount, isAccountFlagged };

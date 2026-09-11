// repositories/devicesRepo.js
const admin = require('../firebaseAdmin');
const db = require('./db');
const { COLLECTIONS } = require('../config/constants');

const devicesCol = () => db.collection(COLLECTIONS.DEVICES);

function getDevice(deviceId) {
  return devicesCol().doc(deviceId).get();
}

function createDevice(deviceId, data) {
  return devicesCol().doc(deviceId).set(data);
}

function updateDevice(deviceId, fields) {
  return devicesCol().doc(deviceId).update(fields);
}

function getOwnedDevices(uid) {
  return devicesCol().where('ownerUid', '==', uid).get();
}

function getSharedDevices(uid) {
  return devicesCol().where('authorizedUids', 'array-contains', uid).get();
}

async function getOwnedAndSharedDevices(uid) {
  const [ownedSnap, sharedSnap] = await Promise.all([getOwnedDevices(uid), getSharedDevices(uid)]);
  return { ownedSnap, sharedSnap };
}

function grantAccess(deviceId, requesterUid, level) {
  return devicesCol()
    .doc(deviceId)
    .update({
      [`authorizedUsers.${requesterUid}`]: { level, grantedAt: Date.now() },
      authorizedUids: admin.firestore.FieldValue.arrayUnion(requesterUid),
    });
}

// --- Histórico de ações (subcoleção por dispositivo) ---

/// Regista uma ação real (nunca uma tentativa suspeita — essas ficam só
/// em `suspiciousActivity`, de propósito). Falha em silêncio — nunca deve
/// impedir a ação em si de continuar.
async function addHistoryEntry(deviceId, uid, action, extra) {
  try {
    await devicesCol().doc(deviceId).collection('history').add({
      uid,
      action,
      extra: extra || null,
      timestamp: Date.now(),
    });
  } catch (err) {
    // Intencional — ver nota acima.
  }
}

function getRecentHistory(deviceId, limit) {
  return devicesCol().doc(deviceId).collection('history').orderBy('timestamp', 'desc').limit(limit).get();
}

// --- Anti-repetição de comandos (nonce) ---

async function isNonceUsed(deviceId, nonce) {
  const snap = await devicesCol().doc(deviceId).collection('usedNonces').doc(nonce).get();
  return snap.exists;
}

function markNonceUsed(deviceId, nonce) {
  return devicesCol().doc(deviceId).collection('usedNonces').doc(nonce).set({ usedAt: Date.now() });
}

module.exports = {
  getDevice,
  createDevice,
  updateDevice,
  getOwnedDevices,
  getSharedDevices,
  getOwnedAndSharedDevices,
  grantAccess,
  addHistoryEntry,
  getRecentHistory,
  isNonceUsed,
  markNonceUsed,
};

// services/historyService.js
const devicesRepo = require('../repositories/devicesRepo');
const userLookupService = require('./userLookupService');

const HISTORY_PER_DEVICE_LIMIT = 20;
const HISTORY_TOTAL_LIMIT = 50;

async function listMyHistory(uid) {
  const { ownedSnap, sharedSnap } = await devicesRepo.getOwnedAndSharedDevices(uid);
  const deviceDocs = [...ownedSnap.docs, ...sharedSnap.docs];
  if (deviceDocs.length === 0) return { entries: [] };

  const perDeviceEntries = await Promise.all(
    deviceDocs.map(async (deviceDoc) => {
      const historySnap = await devicesRepo.getRecentHistory(deviceDoc.id, HISTORY_PER_DEVICE_LIMIT);
      const brand = deviceDoc.data().brand || null;
      return historySnap.docs.map((doc) => ({ deviceId: deviceDoc.id, brand, ...doc.data() }));
    }),
  );

  let entries = perDeviceEntries.flat();
  entries.sort((a, b) => b.timestamp - a.timestamp);
  entries = entries.slice(0, HISTORY_TOTAL_LIMIT);

  const namesByUid = await userLookupService.getDisplayNames(entries.map((e) => e.uid));
  return { entries: entries.map((e) => ({ ...e, actorName: namesByUid[e.uid] || 'Utilizador' })) };
}

module.exports = { listMyHistory };

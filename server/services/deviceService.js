// services/deviceService.js
const { httpError } = require('../lib/httpError');
const devicesRepo = require('../repositories/devicesRepo');
const accessRequestsRepo = require('../repositories/accessRequestsRepo');
const userLookupService = require('./userLookupService');
const { VALID_LEVELS } = require('../config/constants');

async function registerDevice(uid, isGuestAccount, { deviceId, brand, name }) {
  if (isGuestAccount) {
    throw httpError('permission-denied', 'Cria uma conta para registar esta trotinete como tua.');
  }

  const snap = await devicesRepo.getDevice(deviceId);
  if (snap.exists) {
    const data = snap.data();
    if (data.ownerUid !== uid) {
      throw httpError('already-exists', 'Esta trotinete já está registada a outra conta.');
    }
    return { alreadyOwned: true };
  }

  await devicesRepo.createDevice(deviceId, {
    ownerUid: uid,
    brand: brand || null,
    name: name || null,
    authorizedUsers: {},
    registeredAt: Date.now(),
  });
  await devicesRepo.addHistoryEntry(deviceId, uid, 'registered', { brand: brand || null });
  return { alreadyOwned: false };
}

async function listMyDevices(uid) {
  const { ownedSnap, sharedSnap } = await devicesRepo.getOwnedAndSharedDevices(uid);

  const toItem = (doc, isOwner) => {
    const d = doc.data();
    return {
      deviceId: doc.id,
      brand: d.brand || null,
      name: d.name || null,
      isOwner,
      level: isOwner ? 'owner' : d.authorizedUsers?.[uid]?.level || 'limited',
      stolen: d.status === 'stolen',
    };
  };

  return {
    devices: [
      ...ownedSnap.docs.map((doc) => toItem(doc, true)),
      ...sharedSnap.docs.map((doc) => toItem(doc, false)),
    ],
  };
}

async function setStolenStatus(uid, { deviceId, stolen }) {
  const snap = await devicesRepo.getDevice(deviceId);
  if (!snap.exists) throw httpError('not-found', 'Dispositivo não encontrado.');
  if (snap.data().ownerUid !== uid) throw httpError('permission-denied', 'Só o dono pode reportar isto.');

  await devicesRepo.updateDevice(deviceId, {
    status: stolen ? 'stolen' : 'normal',
    stolenReportedAt: stolen ? Date.now() : null,
  });
  await devicesRepo.addHistoryEntry(deviceId, uid, stolen ? 'reported_stolen' : 'marked_recovered', null);
  return { ok: true };
}

async function requestDeviceAccess(uid, isGuestAccount, { deviceId, message }) {
  if (isGuestAccount) throw httpError('permission-denied', 'Cria uma conta para pedir acesso.');

  const deviceSnap = await devicesRepo.getDevice(deviceId);
  if (!deviceSnap.exists) throw httpError('not-found', 'Dispositivo não encontrado.');
  const device = deviceSnap.data();
  if (device.ownerUid === uid || device.authorizedUsers?.[uid]) {
    return { alreadyHasAccess: true };
  }

  const existing = await accessRequestsRepo.findPendingByRequester(deviceId, uid);
  if (!existing.empty) {
    return { alreadyHasAccess: false, requestId: existing.docs[0].id };
  }

  const ref = await accessRequestsRepo.create({
    deviceId,
    requesterUid: uid,
    ownerUid: device.ownerUid,
    message: message || null,
    status: 'pending',
    createdAt: Date.now(),
  });
  return { alreadyHasAccess: false, requestId: ref.id };
}

async function listIncomingAccessRequests(uid) {
  const snap = await accessRequestsRepo.findPendingForOwner(uid);

  const requests = await Promise.all(
    snap.docs.map(async (doc) => {
      const data = doc.data();
      const requesterName = await userLookupService.getDisplayName(data.requesterUid);
      return {
        requestId: doc.id,
        deviceId: data.deviceId,
        message: data.message,
        createdAt: data.createdAt,
        requesterUid: data.requesterUid,
        requesterName,
      };
    }),
  );
  return { requests };
}

async function listMyAccessRequests(uid) {
  const snap = await accessRequestsRepo.findAllByRequester(uid);
  return { requests: snap.docs.map((doc) => ({ requestId: doc.id, ...doc.data() })) };
}

async function respondToAccessRequest(uid, { requestId, approve, level }) {
  const snap = await accessRequestsRepo.get(requestId);
  if (!snap.exists) throw httpError('not-found', 'Pedido não encontrado.');
  const data = snap.data();
  if (data.ownerUid !== uid) throw httpError('permission-denied', 'Só o dono pode responder a este pedido.');
  if (data.status !== 'pending') throw httpError('failed-precondition', 'Este pedido já foi respondido.');

  if (!approve) {
    await accessRequestsRepo.update(requestId, { status: 'denied', respondedAt: Date.now() });
    return { approved: false };
  }

  const grantedLevel = VALID_LEVELS.includes(level) ? level : 'limited';
  await devicesRepo.grantAccess(data.deviceId, data.requesterUid, grantedLevel);
  await accessRequestsRepo.update(requestId, { status: 'approved', respondedAt: Date.now(), grantedLevel });
  await devicesRepo.addHistoryEntry(data.deviceId, data.requesterUid, 'access_granted', {
    level: grantedLevel,
    grantedBy: uid,
  });
  return { approved: true, level: grantedLevel };
}

module.exports = {
  registerDevice,
  listMyDevices,
  setStolenStatus,
  requestDeviceAccess,
  listIncomingAccessRequests,
  listMyAccessRequests,
  respondToAccessRequest,
};

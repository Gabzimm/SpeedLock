// services/profileService.js
const { httpError } = require('../lib/httpError');
const usersRepo = require('../repositories/usersRepo');
const devicesRepo = require('../repositories/devicesRepo');
const authRepo = require('../repositories/firebaseAuthRepo');

async function updateProfile(uid, fields) {
  // `fields` já vem validado e "limpo" pelo schema (validation/profileSchemas.js)
  // — só campos presentes entram no update, o resto mantém-se como estava
  // (comportamento de merge do Firestore).
  await usersRepo.updateProfile(uid, fields);
  return { ok: true };
}

function publicProfileOf(uid, userRecord, profileDoc) {
  const data = profileDoc.exists ? profileDoc.data() : {};
  return {
    uid,
    name: userRecord.displayName || 'Utilizador',
    bio: data.bio || '',
    bannerColor: data.bannerColor || '#6D28D9',
    accentColor: data.accentColor || '#8B5CF6',
    avatarUrl: data.avatarUrl || null,
  };
}

async function getDeviceMembersProfiles(uid, { deviceId }) {
  const deviceSnap = await devicesRepo.getDevice(deviceId);
  if (!deviceSnap.exists) throw httpError('not-found', 'Dispositivo não encontrado.');
  const device = deviceSnap.data();
  const isOwner = device.ownerUid === uid;
  const isAuthorized = Boolean(device.authorizedUsers && device.authorizedUsers[uid]);
  if (!isOwner && !isAuthorized) throw httpError('permission-denied', 'Sem acesso a este dispositivo.');

  const memberUids = [device.ownerUid, ...Object.keys(device.authorizedUsers || {})];
  const uniqueUids = [...new Set(memberUids)];

  const members = await Promise.all(
    uniqueUids.map(async (memberUid) => {
      const [userRecord, profileDoc] = await Promise.all([
        authRepo.getUser(memberUid).catch(() => null),
        usersRepo.getProfileDoc(memberUid),
      ]);
      if (!userRecord) return null;
      return { ...publicProfileOf(memberUid, userRecord, profileDoc), isOwner: memberUid === device.ownerUid };
    }),
  );

  return { members: members.filter(Boolean) };
}

module.exports = { updateProfile, getDeviceMembersProfiles };

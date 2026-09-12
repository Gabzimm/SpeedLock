// services/commandService.js
//
// A parte mais sensível do backend: nenhum comando chega à trotinete
// sem passar por aqui primeiro. Ver o aviso longo original sobre a
// correção feita — pedidos suspeitos respondem com ERRO, nunca com um
// sucesso falso, porque a app não tem como distinguir uma coisa da
// outra antes de mandar bytes reais por BLE.
const { httpError } = require('../lib/httpError');
const { signPayload } = require('../lib/crypto');
const devicesRepo = require('../repositories/devicesRepo');
const securityService = require('./securityService');
const {
  COMMAND_SIGNING_KEY,
  OFFLINE_SIGNING_KEY,
  OFFLINE_TOKEN_VALID_DAYS,
  COMMAND_TOKEN_VALID_MS,
  MIN_LEVEL_FOR_COMMAND,
  LEVEL_RANK,
} = require('../config/constants');

async function requestDeviceCommand(uid, isGuestAccount, { deviceId, command, params, nonce }) {
  const deny = async (reason) => {
    await securityService.flagSuspicious(uid, deviceId, reason);
    throw httpError('failed-precondition', 'Não foi possível processar o pedido. Tenta novamente.');
  };

  if (!command || !MIN_LEVEL_FOR_COMMAND[command]) {
    return deny('unknown_command');
  }

  if (await securityService.isAccountFlagged(uid)) {
    return deny('flagged_account_retry');
  }

  if (isGuestAccount) {
    if (command !== 'setSpeedLimit') return deny('guest_restricted_command');
    if (!deviceId) return deny('missing_device_id');

    if (nonce) {
      if (await devicesRepo.isNonceUsed(deviceId, nonce)) return deny('replayed_nonce');
      await devicesRepo.markNonceUsed(deviceId, nonce);
    }

    return signPayload(
      { deviceId, command, params, nonce, issuedAt: Date.now(), expiresAt: Date.now() + COMMAND_TOKEN_VALID_MS },
      COMMAND_SIGNING_KEY,
    );
  }

  const deviceSnap = await devicesRepo.getDevice(deviceId || '');
  if (!deviceId || !deviceSnap.exists) return deny('unknown_device');
  const device = deviceSnap.data();

  const accessLevel = device.ownerUid === uid ? 'owner' : device.authorizedUsers?.[uid]?.level;
  if (!accessLevel) return deny('unauthorized_device_access');
  if (LEVEL_RANK[accessLevel] < LEVEL_RANK[MIN_LEVEL_FOR_COMMAND[command]]) {
    return deny('insufficient_access_level');
  }

  if (nonce) {
    if (await devicesRepo.isNonceUsed(deviceId, nonce)) return deny('replayed_nonce');
    await devicesRepo.markNonceUsed(deviceId, nonce);
  }

  await devicesRepo.addHistoryEntry(deviceId, uid, command, params || null);
  return signPayload(
    { deviceId, command, params, nonce, issuedAt: Date.now(), expiresAt: Date.now() + COMMAND_TOKEN_VALID_MS },
    COMMAND_SIGNING_KEY,
  );
}

async function issueOfflineSpeedLimitToken(uid, isGuestAccount, { deviceId }) {
  if (isGuestAccount) throw httpError('permission-denied', 'Modo offline exige conta.');

  const deviceSnap = await devicesRepo.getDevice(deviceId);
  if (!deviceSnap.exists) throw httpError('not-found', 'Dispositivo não encontrado.');
  const device = deviceSnap.data();
  const accessLevel = device.ownerUid === uid ? 'owner' : device.authorizedUsers?.[uid]?.level;
  if (!accessLevel || LEVEL_RANK[accessLevel] < LEVEL_RANK[MIN_LEVEL_FOR_COMMAND.setSpeedLimit]) {
    throw httpError('permission-denied', 'Sem nível de acesso suficiente.');
  }

  const expiresAt = Date.now() + OFFLINE_TOKEN_VALID_DAYS * 24 * 60 * 60 * 1000;
  return signPayload({ uid, deviceId, command: 'setSpeedLimit', issuedAt: Date.now(), expiresAt }, OFFLINE_SIGNING_KEY);
}

module.exports = { requestDeviceCommand, issueOfflineSpeedLimitToken };

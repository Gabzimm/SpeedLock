// services/authService.js
const { httpError } = require('../lib/httpError');
const { generateCode, hashToken, generateDeviceToken } = require('../lib/crypto');
const authRepo = require('../repositories/firebaseAuthRepo');
const usersRepo = require('../repositories/usersRepo');
const verificationsRepo = require('../repositories/verificationsRepo');
const emailService = require('./emailService');
const geoService = require('./geoService');
const { TRUSTED_DEVICE_DAYS, CODE_TTL_MINUTES, MAX_CODE_ATTEMPTS } = require('../config/constants');

async function registerUser(req, { name, email, password }) {
  let userRecord;
  try {
    userRecord = await authRepo.createUser({ email, password, displayName: name });
  } catch (err) {
    if (err.code === 'auth/email-already-exists') {
      throw httpError('already-exists', 'Já existe uma conta com este email.');
    }
    throw httpError('internal', 'Não foi possível criar a conta.');
  }

  const location = geoService.getRequestLocation(req);
  if (location) {
    await usersRepo.addTrustedLocation(userRecord.uid, location);
  }

  return { uid: userRecord.uid };
}

async function checkLoginLocation(req, uid, { deviceToken }) {
  if (deviceToken) {
    const tokenDoc = await usersRepo.getTrustedDevice(uid, hashToken(deviceToken));
    if (tokenDoc.exists && tokenDoc.data().expiresAt > Date.now()) {
      return { trusted: true };
    }
  }

  const location = geoService.getRequestLocation(req);
  if (location && (await usersRepo.hasTrustedLocation(uid, location))) {
    return { trusted: true };
  }

  const code = generateCode();
  const verificationRef = await verificationsRepo.createVerification({
    uid,
    code,
    location,
    attempts: 0,
    createdAt: Date.now(),
    expiresAt: Date.now() + CODE_TTL_MINUTES * 60 * 1000,
  });

  const userRecord = await authRepo.getUser(uid);
  await emailService.sendCodeEmail(userRecord.email, code, 'login');

  return { trusted: false, verificationId: verificationRef.id };
}

async function confirmLoginVerification(uid, { verificationId, code, rememberDevice }) {
  const snap = await verificationsRepo.getVerification(verificationId);
  if (!snap.exists) throw httpError('not-found', 'Verificação inválida.');
  const data = snap.data();

  if (data.uid !== uid) throw httpError('permission-denied', 'Verificação inválida.');
  if (Date.now() > data.expiresAt) throw httpError('deadline-exceeded', 'Código expirado.');
  if (data.attempts >= MAX_CODE_ATTEMPTS) throw httpError('resource-exhausted', 'Demasiadas tentativas.');
  if (data.code !== code) {
    await verificationsRepo.incrementVerificationAttempts(verificationId);
    throw httpError('invalid-argument', 'Código incorreto.');
  }

  if (data.location) {
    await usersRepo.addTrustedLocation(data.uid, data.location);
  }
  await verificationsRepo.deleteVerification(verificationId);

  const result = {};
  if (rememberDevice) {
    const rawToken = generateDeviceToken();
    const expiresAt = Date.now() + TRUSTED_DEVICE_DAYS * 24 * 60 * 60 * 1000;
    await usersRepo.setTrustedDevice(data.uid, hashToken(rawToken), expiresAt);
    result.deviceToken = rawToken;
  }
  return result;
}

async function requestPasswordReset({ email }) {
  try {
    const userRecord = await authRepo.getUserByEmail(email);
    const code = generateCode();
    await verificationsRepo.setPasswordReset(userRecord.uid, {
      email,
      code,
      attempts: 0,
      createdAt: Date.now(),
      expiresAt: Date.now() + CODE_TTL_MINUTES * 60 * 1000,
    });
    await emailService.sendCodeEmail(email, code, 'reset');
  } catch (err) {
    // Propositado: utilizador não encontrado ou falha de envio nunca
    // deve dizer ao chamador qual dos dois foi — evita confirmar se um
    // email existe ou não na base de dados.
  }
  return { ok: true };
}

async function confirmPasswordReset({ email, code, newPassword }) {
  const userRecord = await authRepo.getUserByEmail(email).catch(() => null);
  if (!userRecord) throw httpError('invalid-argument', 'Código incorreto.');

  const snap = await verificationsRepo.getPasswordReset(userRecord.uid);
  if (!snap.exists) throw httpError('invalid-argument', 'Código incorreto.');
  const data = snap.data();

  if (Date.now() > data.expiresAt) throw httpError('deadline-exceeded', 'Código expirado.');
  if (data.attempts >= MAX_CODE_ATTEMPTS) throw httpError('resource-exhausted', 'Demasiadas tentativas.');
  if (data.code !== code) {
    await verificationsRepo.incrementPasswordResetAttempts(userRecord.uid);
    throw httpError('invalid-argument', 'Código incorreto.');
  }

  await authRepo.updateUser(userRecord.uid, { password: newPassword });
  await verificationsRepo.deletePasswordReset(userRecord.uid);
  return { ok: true };
}

async function finalizeGuestRegistration(req, uid, { name }) {
  if (name) {
    await authRepo.updateUser(uid, { displayName: name });
  }

  const location = geoService.getRequestLocation(req);
  if (location && !(await usersRepo.hasTrustedLocation(uid, location))) {
    await usersRepo.addTrustedLocation(uid, location);
  }
  return { ok: true };
}

module.exports = {
  registerUser,
  checkLoginLocation,
  confirmLoginVerification,
  requestPasswordReset,
  confirmPasswordReset,
  finalizeGuestRegistration,
};

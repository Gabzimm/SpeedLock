// repositories/verificationsRepo.js
const admin = require('../firebaseAdmin');
const db = require('./db');
const { COLLECTIONS } = require('../config/constants');

const verificationsCol = () => db.collection(COLLECTIONS.VERIFICATIONS);
const passwordResetsCol = () => db.collection(COLLECTIONS.PASSWORD_RESETS);

// --- Código de verificação de login (localização nova) ---

function createVerification(data) {
  return verificationsCol().add(data);
}

function getVerification(id) {
  return verificationsCol().doc(id).get();
}

function incrementVerificationAttempts(id) {
  return verificationsCol().doc(id).update({ attempts: admin.firestore.FieldValue.increment(1) });
}

function deleteVerification(id) {
  return verificationsCol().doc(id).delete();
}

// --- Código de recuperação de senha ---

function setPasswordReset(uid, data) {
  return passwordResetsCol().doc(uid).set(data);
}

function getPasswordReset(uid) {
  return passwordResetsCol().doc(uid).get();
}

function incrementPasswordResetAttempts(uid) {
  return passwordResetsCol().doc(uid).update({ attempts: admin.firestore.FieldValue.increment(1) });
}

function deletePasswordReset(uid) {
  return passwordResetsCol().doc(uid).delete();
}

module.exports = {
  createVerification,
  getVerification,
  incrementVerificationAttempts,
  deleteVerification,
  setPasswordReset,
  getPasswordReset,
  incrementPasswordResetAttempts,
  deletePasswordReset,
};

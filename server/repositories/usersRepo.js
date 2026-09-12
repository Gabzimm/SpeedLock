// repositories/usersRepo.js
//
// Tudo o que toca na coleção `users` e nas suas subcoleções. Nenhuma
// regra de negócio aqui — só "ler isto", "escrever aquilo".
const db = require('./db');
const { COLLECTIONS } = require('../config/constants');

const usersCol = () => db.collection(COLLECTIONS.USERS);

// --- Perfil (bio, cores, avatar) ---

function getProfileDoc(uid) {
  return usersCol().doc(uid).get();
}

function updateProfile(uid, fields) {
  return usersCol().doc(uid).set(fields, { merge: true });
}

// --- Localizações confiadas (login sem pedir código outra vez) ---

function addTrustedLocation(uid, location) {
  return usersCol()
    .doc(uid)
    .collection('trustedLocations')
    .add({ ...location, trustedAt: Date.now() });
}

async function hasTrustedLocation(uid, location) {
  const snap = await usersCol()
    .doc(uid)
    .collection('trustedLocations')
    .where('city', '==', location.city)
    .where('country', '==', location.country)
    .limit(1)
    .get();
  return !snap.empty;
}

// --- Dispositivos confiados (token local, evita pedir código) ---

function getTrustedDevice(uid, tokenHash) {
  return usersCol().doc(uid).collection('trustedDevices').doc(tokenHash).get();
}

function setTrustedDevice(uid, tokenHash, expiresAt) {
  return usersCol().doc(uid).collection('trustedDevices').doc(tokenHash).set({ createdAt: Date.now(), expiresAt });
}

// --- Estado de segurança da conta (contagem de tentativas suspeitas) ---

function securityDocRef(uid) {
  return usersCol().doc(uid).collection('meta').doc('security');
}

function getSecurityDoc(uid) {
  return securityDocRef(uid).get();
}

function setSecurityDoc(uid, fields) {
  return securityDocRef(uid).set(fields, { merge: true });
}

module.exports = {
  getProfileDoc,
  updateProfile,
  addTrustedLocation,
  hasTrustedLocation,
  getTrustedDevice,
  setTrustedDevice,
  getSecurityDoc,
  setSecurityDoc,
};

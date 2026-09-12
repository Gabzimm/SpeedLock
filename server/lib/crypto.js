// lib/crypto.js
//
// Funções puras de criptografia/aleatoriedade — sem nenhuma dependência
// de Firestore ou de outros serviços, por isso vivem em lib/ e não em
// services/.
const crypto = require('crypto');

function generateCode() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function generateDeviceToken() {
  return crypto.randomBytes(32).toString('hex');
}

function signPayload(payload, key) {
  const json = JSON.stringify(payload);
  const signature = crypto.createHmac('sha256', key).update(json).digest('hex');
  return { payload, signature };
}

module.exports = { generateCode, hashToken, generateDeviceToken, signPayload };

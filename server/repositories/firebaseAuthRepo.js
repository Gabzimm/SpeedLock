// repositories/firebaseAuthRepo.js
const admin = require('../firebaseAdmin');

function createUser({ email, password, displayName }) {
  return admin.auth().createUser({ email, password, displayName });
}

function getUser(uid) {
  return admin.auth().getUser(uid);
}

function getUserByEmail(email) {
  return admin.auth().getUserByEmail(email);
}

function updateUser(uid, fields) {
  return admin.auth().updateUser(uid, fields);
}

module.exports = { createUser, getUser, getUserByEmail, updateUser };

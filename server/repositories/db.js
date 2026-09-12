// repositories/db.js
//
// Uma só instância do Firestore, partilhada por todos os repositórios.
const admin = require('../firebaseAdmin');

module.exports = admin.firestore();

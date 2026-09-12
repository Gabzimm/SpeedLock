// Fora das Cloud Functions, a Admin SDK não recebe credenciais
// automaticamente — precisa de uma chave de conta de serviço. Gerar em:
// Firebase Console → Definições do projeto → Contas de serviço →
// "Gerar nova chave privada". Guardar o ficheiro fora do controlo de
// versões (ver .gitignore) e apontar o caminho em GOOGLE_APPLICATION_CREDENTIALS
// no .env — nunca comitar o ficheiro em si.
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

module.exports = admin;

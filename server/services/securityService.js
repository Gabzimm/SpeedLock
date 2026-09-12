// services/securityService.js
const securityRepo = require('../repositories/securityRepo');

/// "Assinalar como suspeito" é uma única ação de negócio que, por baixo,
/// mexe em duas coisas: o registo de auditoria (suspiciousActivity) e o
/// contador que decide se a conta fica bloqueada. Viviam já juntas no
/// código antigo — aqui só ficou explícito que é uma operação de
/// serviço, não dois acessos a dados independentes.
async function flagSuspicious(uid, deviceId, reason) {
  await securityRepo.logSuspiciousActivity(uid, deviceId, reason);
  await securityRepo.incrementSuspiciousCount(uid);
}

async function isAccountFlagged(uid) {
  return securityRepo.isAccountFlagged(uid);
}

module.exports = { flagSuspicious, isAccountFlagged };

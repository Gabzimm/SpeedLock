// services/userAdminService.js
//
// Só para o painel de administração — nunca chamado a partir de rotas
// que um utilizador normal da app consegue atingir. Reaproveita os
// serviços que já existem (deviceService, historyService,
// securityService) em vez de duplicar lógica: esses serviços já
// recebem um `uid` como parâmetro em vez de irem buscar `req.auth.uid`
// eles próprios, por isso funcionam da mesma forma quer seja "o meu
// próprio histórico" quer seja "o histórico de outra pessoa, visto por
// um admin".
const { httpError } = require('../lib/httpError');
const admin = require('../firebaseAdmin');
const authRepo = require('../repositories/firebaseAuthRepo');
const deviceService = require('./deviceService');
const historyService = require('./historyService');
const securityService = require('./securityService');

const MAX_USERS_SCANNED_FOR_SEARCH = 5000;

function toSummary(userRecord) {
  return {
    uid: userRecord.uid,
    email: userRecord.email || null,
    name: userRecord.displayName || null,
    createdAt: userRecord.metadata?.creationTime || null,
    lastSignInAt: userRecord.metadata?.lastSignInTime || null,
    disabled: userRecord.disabled === true,
  };
}

/// Sem termo de pesquisa: pagina normalmente pela Firebase Auth.
/// Com termo de pesquisa: a Firebase Auth não tem pesquisa por texto —
/// percorremos páginas de utilizadores e filtramos nós próprios, até um
/// limite de segurança (`MAX_USERS_SCANNED_FOR_SEARCH`). Para uma escala
/// muito maior do que isto (dezenas de milhares de contas), isto
/// precisaria de um índice de pesquisa dedicado em vez de percorrer tudo.
async function listUsers({ search, pageToken, pageSize = 50 }) {
  if (!search) {
    const page = await admin.auth().listUsers(pageSize, pageToken || undefined);
    return { users: page.users.map(toSummary), nextPageToken: page.pageToken || null, truncated: false };
  }

  const term = search.toLowerCase();
  const matched = [];
  let token;
  let scanned = 0;
  let truncated = false;

  do {
    const page = await admin.auth().listUsers(1000, token);
    scanned += page.users.length;
    for (const user of page.users) {
      if (user.email?.toLowerCase().includes(term) || user.displayName?.toLowerCase().includes(term)) {
        matched.push(user);
      }
    }
    token = page.pageToken;
    if (scanned >= MAX_USERS_SCANNED_FOR_SEARCH) {
      truncated = Boolean(token); // ainda havia mais para percorrer quando paramos
      break;
    }
  } while (token && matched.length < pageSize * 3);

  return { users: matched.slice(0, pageSize).map(toSummary), nextPageToken: null, truncated };
}

async function getUserDetail(uid) {
  const userRecord = await authRepo.getUser(uid).catch(() => null);
  if (!userRecord) throw httpError('not-found', 'Utilizador não encontrado.');

  const [devicesResult, historyResult, flagged] = await Promise.all([
    deviceService.listMyDevices(uid),
    historyService.listMyHistory(uid),
    securityService.isAccountFlagged(uid),
  ]);

  return {
    ...toSummary(userRecord),
    flagged,
    devices: devicesResult.devices,
    recentActivity: historyResult.entries.slice(0, 30),
  };
}

module.exports = { listUsers, getUserDetail };

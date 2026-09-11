// services/userLookupService.js
//
// `admin.auth().getUser(uid)` é um pedido de rede à Firebase por cada
// chamada. Ecrãs como o histórico ou os pedidos de acesso pendentes
// mostram o nome de várias pessoas de uma vez, e a mesma pessoa aparece
// repetidamente entre pedidos (o dono de uma trotinete aparece em quase
// todas as entradas do histórico dela, por exemplo) — sem cache, isso é
// um pedido à Firebase por entrada, todos os pedidos, para a mesma
// informação que raramente muda.
const admin = require('../firebaseAdmin');
const { TtlCache } = require('../lib/cache');
const { USER_LOOKUP_CACHE_TTL_MS } = require('../config/constants');

const cache = new TtlCache(USER_LOOKUP_CACHE_TTL_MS);

async function getDisplayName(uid) {
  return cache.getOrFetch(uid, async () => {
    const user = await admin.auth().getUser(uid).catch(() => null);
    return user?.displayName || 'Utilizador';
  });
}

/// Versão para várias contas de uma vez — só pede à Firebase as que
/// ainda não estão em cache.
async function getDisplayNames(uids) {
  const uniqueUids = [...new Set(uids)];
  const entries = await Promise.all(uniqueUids.map(async (uid) => [uid, await getDisplayName(uid)]));
  return Object.fromEntries(entries);
}

module.exports = { getDisplayName, getDisplayNames };

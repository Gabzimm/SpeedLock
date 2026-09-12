// lib/cache.js
//
// Cache simples em memória, com expiração. Usado para não pedir o mesmo
// utilizador à Firebase Auth vezes sem conta em pedidos que juntam nomes
// de várias pessoas (histórico, pedidos de acesso, membros de um
// dispositivo) — a mesma pessoa aparece muitas vezes nesses ecrãs.
//
// Aviso: isto vive na memória deste processo Node. Se um dia isto correr
// em mais do que um processo ao mesmo tempo (vários workers, ou várias
// instâncias atrás de um load balancer), cada processo tem a sua própria
// cópia — nunca fica desatualizado de forma perigosa (só significa que
// uma mudança de nome pode demorar até TTL a aparecer em todo o lado),
// por isso continua seguro de usar, só não é uma cache "partilhada".
class TtlCache {
  constructor(ttlMs) {
    this.ttlMs = ttlMs;
    this.map = new Map();
  }

  get(key) {
    const hit = this.map.get(key);
    if (!hit) return undefined;
    if (Date.now() > hit.expiresAt) {
      this.map.delete(key);
      return undefined;
    }
    return hit.value;
  }

  set(key, value) {
    this.map.set(key, { value, expiresAt: Date.now() + this.ttlMs });
  }

  /// Busca em cache; se não existir, chama `fetcher()` e guarda o
  /// resultado. Evita o padrão repetido "get, se não existir pede e
  /// guarda" em cada sítio que precisa disto.
  async getOrFetch(key, fetcher) {
    const cached = this.get(key);
    if (cached !== undefined) return cached;
    const value = await fetcher();
    this.set(key, value);
    return value;
  }
}

module.exports = { TtlCache };

// services/geoService.js
const geoip = require('geoip-lite');

/// Lê a localização aproximada a partir do IP real do pedido HTTP. Nunca
/// confiar em nada que a app diga sobre a sua própria localização — só
/// isto, lido pelo próprio servidor, conta. Atrás de um proxy (Nginx),
/// `app.set('trust proxy', true)` em index.js é o que faz `req.ip` já vir
/// correto; o cabeçalho é lido à mesma como reforço.
function getRequestLocation(req) {
  const ip =
    req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip || req.socket?.remoteAddress;
  if (!ip) return null;
  const geo = geoip.lookup(ip);
  if (!geo) return null;
  return { city: geo.city || 'desconhecida', country: geo.country };
}

module.exports = { getRequestLocation };

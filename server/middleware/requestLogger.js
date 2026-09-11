// middleware/requestLogger.js
//
// Uma linha de log estruturado por pedido, depois de terminar (para já
// incluir o status e a duração). Inclui o uid quando já há sessão
// identificada (attachAuth corre antes disto em cada router), para
// conseguires seguir "o que é que esta conta andou a fazer" sem teres
// de cruzar IPs à mão.
const logger = require('../config/logger');

function requestLogger(req, res, next) {
  const startedAt = process.hrtime.bigint();

  res.on('finish', () => {
    const durationMs = Number(process.hrtime.bigint() - startedAt) / 1e6;
    const entry = {
      method: req.method,
      path: req.originalUrl,
      status: res.statusCode,
      durationMs: Math.round(durationMs * 10) / 10,
      uid: req.auth?.uid || null,
      ip: req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip,
    };
    if (res.statusCode >= 500) {
      logger.error(entry, 'request_failed');
    } else if (res.statusCode >= 400) {
      logger.warn(entry, 'request_rejected');
    } else {
      logger.info(entry, 'request_ok');
    }
  });

  next();
}

module.exports = requestLogger;

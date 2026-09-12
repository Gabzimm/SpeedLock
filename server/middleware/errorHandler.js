// middleware/errorHandler.js
//
// Middleware de erro do Express — tem de ser o último `app.use`, com 4
// argumentos (é isso que diz ao Express "isto é o handler de erro").
// Qualquer `throw httpError(...)` dentro de uma rota (envolvida em
// `asyncRoute`) acaba aqui, nunca como uma exceção não tratada que
// derruba o processo.
const { HttpError } = require('../lib/httpError');
const logger = require('../config/logger');

function errorHandler(err, req, res, next) {
  if (err instanceof HttpError) {
    // Erros esperados (validação, permissões, etc.) — nível "warn", não
    // "error": não precisam de acordar ninguém a meio da noite.
    logger.warn(
      { code: err.code, status: err.status, path: req.originalUrl, uid: req.auth?.uid || null },
      err.message,
    );
    return res.status(err.status).json({ code: err.code, message: err.message });
  }

  // Qualquer coisa que chegue aqui NÃO era esperada — stack trace
  // completo no log, e uma mensagem genérica para quem fez o pedido
  // (nunca detalhes internos).
  logger.error({ err, path: req.originalUrl, uid: req.auth?.uid || null }, 'unhandled_error');
  res.status(500).json({ code: 'internal', message: 'Erro interno do servidor.' });
}

module.exports = errorHandler;

// Mesmos códigos de erro que existiam nas Cloud Functions
// (functions.HttpsError) — só a forma de os transportar muda (HTTP
// status + JSON em vez do wrapper próprio da Firebase). Isto significa
// que o cliente (ApiException no Flutter) continua a poder decidir com
// base no `code`, exatamente como fazia antes com `FirebaseFunctionsException.code`.
class HttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

const CODE_TO_STATUS = {
  'invalid-argument': 400,
  unauthenticated: 401,
  'permission-denied': 403,
  'not-found': 404,
  'already-exists': 409,
  'deadline-exceeded': 408,
  'failed-precondition': 412,
  'resource-exhausted': 429,
  internal: 500,
};

function httpError(code, message) {
  return new HttpError(CODE_TO_STATUS[code] || 500, code, message);
}

/// Envolve um handler async — qualquer erro lançado (incluindo os de
/// httpError) chega ao middleware de erro em vez de derrubar o processo.
function asyncRoute(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

module.exports = { HttpError, httpError, asyncRoute };

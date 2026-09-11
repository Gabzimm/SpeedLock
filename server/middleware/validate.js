// middleware/validate.js
//
// Antes, cada rota validava o corpo do pedido à mão, no meio da lógica
// de negócio — algumas rotas validavam tudo, outras quase nada (ex:
// `updateProfile` validava cor e bio, mas `registerDevice` não validava
// o formato de `deviceId` nenhum). Isto separa "isto está bem formado"
// de "isto é permitido fazer agora" — validação aqui, regras de negócio
// nos serviços.
//
// Usa `zod`: cada rota tem um "schema" (validation/*.js) que descreve a
// forma esperada do corpo do pedido. Se não bater certo, a rota nem
// chega a correr — o pedido é recusado logo, com uma mensagem clara.
const { httpError } = require('../lib/httpError');

function validate(schema) {
  return (req, res, next) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      const message = result.error.issues.map((issue) => issue.message).join('; ');
      return next(httpError('invalid-argument', message || 'Pedido inválido.'));
    }
    // Substitui req.body pela versão validada/normalizada (ex: trim em
    // strings) — o resto do código passa a poder confiar na forma dos
    // dados sem repetir verificações.
    req.body = result.data;
    next();
  };
}

module.exports = { validate };

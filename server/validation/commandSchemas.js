// validation/commandSchemas.js
const { z } = require('zod');
const { deviceIdSchema, commandNameSchema } = require('./shared');

// `command` é validado com uma lista de valores conhecidos (ver
// shared.js) — mas propositadamente NÃO rejeitamos aqui um comando
// desconhecido com erro de validação; isso continua a passar para o
// commandService, que o trata como tentativa suspeita e regista/pune
// como tal. Rejeitar aqui destruiria esse sinal de segurança.
const requestDeviceCommandSchema = z.object({
  deviceId: z.string().trim().max(200).optional(),
  command: z.string().min(1, 'command em falta.'),
  params: z.record(z.string(), z.unknown()).optional(),
  nonce: z.string().max(128).optional(),
});

const issueOfflineSpeedLimitTokenSchema = z.object({
  deviceId: deviceIdSchema,
});

module.exports = { requestDeviceCommandSchema, issueOfflineSpeedLimitTokenSchema, commandNameSchema };

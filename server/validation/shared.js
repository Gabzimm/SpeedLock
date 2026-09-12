// validation/shared.js
const { z } = require('zod');
const { HEX_COLOR_RE, VALID_LEVELS, MIN_LEVEL_FOR_COMMAND, MAX_BIO_LENGTH } = require('../config/constants');

// IDs de dispositivo vêm do BLE/USB/Wi-Fi (ex: "Ninebot-ESD200_88AF") —
// nunca devem conter "/", que quebraria o caminho de um documento
// Firestore (ou pior, mudaria acidentalmente de coleção).
const deviceIdSchema = z
  .string()
  .trim()
  .min(1, 'deviceId em falta.')
  .max(200, 'deviceId demasiado longo.')
  .regex(/^[^/]+$/, 'deviceId inválido.');

const hexColorSchema = z.string().regex(HEX_COLOR_RE, 'Cor inválida — usa o formato #RRGGBB.');

const accessLevelSchema = z.enum(VALID_LEVELS, { errorMap: () => ({ message: 'Nível de acesso inválido.' }) });

const commandNameSchema = z
  .string()
  .refine((v) => Object.prototype.hasOwnProperty.call(MIN_LEVEL_FOR_COMMAND, v), {
    message: 'Comando desconhecido.',
  });

module.exports = { deviceIdSchema, hexColorSchema, accessLevelSchema, commandNameSchema, MAX_BIO_LENGTH };

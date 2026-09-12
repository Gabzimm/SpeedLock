// validation/deviceSchemas.js
const { z } = require('zod');
const { deviceIdSchema, accessLevelSchema } = require('./shared');

const registerDeviceSchema = z.object({
  deviceId: deviceIdSchema,
  brand: z.string().trim().max(60).optional(),
  name: z.string().trim().max(60).optional(),
});

const setStolenStatusSchema = z.object({
  deviceId: deviceIdSchema,
  stolen: z.boolean(),
});

const requestDeviceAccessSchema = z.object({
  deviceId: deviceIdSchema,
  message: z.string().trim().max(200).optional(),
});

const respondToAccessRequestSchema = z.object({
  requestId: z.string().min(1, 'requestId em falta.'),
  approve: z.boolean(),
  level: accessLevelSchema.optional(),
});

module.exports = {
  registerDeviceSchema,
  setStolenStatusSchema,
  requestDeviceAccessSchema,
  respondToAccessRequestSchema,
};

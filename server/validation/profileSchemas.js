// validation/profileSchemas.js
const { z } = require('zod');
const { deviceIdSchema, hexColorSchema, MAX_BIO_LENGTH } = require('./shared');

const updateProfileSchema = z.object({
  bio: z.string().max(MAX_BIO_LENGTH, `Bio até ${MAX_BIO_LENGTH} caracteres.`).optional(),
  bannerColor: hexColorSchema.optional(),
  accentColor: hexColorSchema.optional(),
  avatarUrl: z.string().url('URL de avatar inválido.').max(2048).optional(),
});

const getDeviceMembersProfilesSchema = z.object({
  deviceId: deviceIdSchema,
});

module.exports = { updateProfileSchema, getDeviceMembersProfilesSchema };

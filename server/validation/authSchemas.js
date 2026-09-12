// validation/authSchemas.js
const { z } = require('zod');

const registerUserSchema = z.object({
  name: z.string().trim().max(80, 'Nome demasiado longo.').optional(),
  email: z.string().trim().toLowerCase().email('Email inválido.'),
  password: z.string().min(8, 'A senha precisa de pelo menos 8 caracteres.').max(128),
});

const checkLoginLocationSchema = z.object({
  deviceToken: z.string().max(256).optional(),
});

const confirmLoginVerificationSchema = z.object({
  verificationId: z.string().min(1, 'Verificação em falta.'),
  code: z.string().regex(/^\d{6}$/, 'Código inválido.'),
  rememberDevice: z.boolean().optional(),
});

const requestPasswordResetSchema = z.object({
  email: z.string().trim().toLowerCase().email('Email inválido.'),
});

const confirmPasswordResetSchema = z.object({
  email: z.string().trim().toLowerCase().email('Email inválido.'),
  code: z.string().regex(/^\d{6}$/, 'Código inválido.'),
  newPassword: z.string().min(8, 'A nova senha precisa de pelo menos 8 caracteres.').max(128),
});

const finalizeGuestRegistrationSchema = z.object({
  name: z.string().trim().max(80, 'Nome demasiado longo.').optional(),
});

module.exports = {
  registerUserSchema,
  checkLoginLocationSchema,
  confirmLoginVerificationSchema,
  requestPasswordResetSchema,
  confirmPasswordResetSchema,
  finalizeGuestRegistrationSchema,
};

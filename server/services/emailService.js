// services/emailService.js
const nodemailer = require('nodemailer');
const { CODE_TTL_MINUTES } = require('../config/constants');
const logger = require('../config/logger');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: Number(process.env.SMTP_PORT) || 465,
  secure: true,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

async function sendCodeEmail(email, code, context) {
  const subject =
    context === 'login'
      ? 'SpeedLock — código de verificação de acesso'
      : 'SpeedLock — código de recuperação de senha';
  try {
    await transporter.sendMail({
      from: '"SpeedLock" <no-reply@speedlock.app>',
      to: email,
      subject,
      text: `O teu código é: ${code}\n\nExpira em ${CODE_TTL_MINUTES} minutos. Se não foste tu, ignora este email.`,
    });
  } catch (err) {
    // Um email que falha a enviar não deve aparecer como "erro interno
    // genérico" para quem está a tentar entrar — mas também não convém
    // perder o registo de que o SMTP falhou. Regista e deixa a rota
    // decidir o que fazer a seguir (algumas escondem isto de propósito,
    // ver authService.requestPasswordReset).
    logger.error({ err, email, context }, 'email_send_failed');
    throw err;
  }
}

module.exports = { sendCodeEmail };

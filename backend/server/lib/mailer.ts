import nodemailer from 'nodemailer';

function getSmtpConfig() {
  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASSWORD;
  const from = process.env.SMTP_FROM;

  if (!host || !user || !pass || !from) {
    throw new Error('SMTP_HOST, SMTP_USER, SMTP_PASSWORD, and SMTP_FROM must be configured');
  }

  const port = Number(process.env.SMTP_PORT ?? 587);
  if (!Number.isInteger(port) || port <= 0) {
    throw new Error('SMTP_PORT must be a valid port number');
  }

  return { host, user, pass, from, port };
}

export async function sendVerificationEmail(email: string, code: string) {
  if (process.env.VERIFICATION_DELIVERY === 'console') {
    console.log(`[email verification] ${email}: ${code}`);
    return;
  }

  const config = getSmtpConfig();
  const transporter = nodemailer.createTransport({
    host: config.host,
    port: config.port,
    secure: config.port === 465,
    auth: {
      user: config.user,
      pass: config.pass,
    },
  });

  await transporter.sendMail({
    from: config.from,
    to: email,
    subject: 'Подтверждение e-mail — Smart Light',
    text: `Ваш код подтверждения: ${code}. Он действует 10 минут.`,
  });
}

export async function sendPasswordResetEmail(email: string, code: string) {
  if (process.env.VERIFICATION_DELIVERY === 'console') {
    console.log(`[password reset] ${email}: ${code}`);
    return;
  }

  const config = getSmtpConfig();
  const transporter = nodemailer.createTransport({
    host: config.host,
    port: config.port,
    secure: config.port === 465,
    auth: {
      user: config.user,
      pass: config.pass,
    },
  });

  await transporter.sendMail({
    from: config.from,
    to: email,
    subject: 'Восстановление пароля — Smart Light',
    text: `Ваш код для восстановления пароля: ${code}. Он действует 10 минут.`,
  });
}

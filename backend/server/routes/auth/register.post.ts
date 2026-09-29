import { createError, defineEventHandler, readBody } from 'h3';
import { z } from 'zod';
import { hashPassword } from '../../lib/auth';
import { prisma } from '../../lib/prisma';
import {
  createVerificationCode,
  hashVerificationCode,
} from '../../lib/email_verification';
import { sendVerificationEmail } from '../../lib/mailer';

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(6, 'Password must be at least 6 characters'),
  name: z.string().min(2).optional(),
});

export default defineEventHandler(async (event) => {
  const data = schema.parse(await readBody(event));

  // Нормализуем email: убираем пробелы и приводим к нижнему регистру
  const email = data.email.trim().toLowerCase();

  const existingUser = await prisma.user.findUnique({
    where: { email },
  });

  // Если пользователь существует и уже подтвердил email, блокируем регистрацию
  if (existingUser?.emailVerifiedAt) {
    throw createError({
      statusCode: 409,
      statusMessage: 'User already exists',
    });
  }

  let user;

  if (existingUser) {
    // Пользователь существует, но не подтвердил email.
    // Обновляем его пароль и имя на случай, если он пытается зарегистрироваться заново.
    user = await prisma.user.update({
      where: { id: existingUser.id },
      data: {
        passwordHash: await hashPassword(data.password),
        name: data.name ?? existingUser.name,
      },
      select: {
        id: true,
        email: true,
        name: true,
        createdAt: true,
        emailVerifiedAt: true,
      },
    });
  } else {
    // Пользователя не существует, создаем нового
    user = await prisma.user.create({
      data: {
        email,
        passwordHash: await hashPassword(data.password),
        name: data.name,
      },
      select: {
        id: true,
        email: true,
        name: true,
        createdAt: true,
        emailVerifiedAt: true,
      },
    });
  }

  const code = createVerificationCode();

  // Удаляем старые коды подтверждения, если они были
  await prisma.emailVerificationCode.deleteMany({
    where: { userId: user.id },
  });

  // Создаем новый код
  await prisma.emailVerificationCode.create({
    data: {
      userId: user.id,
      codeHash: hashVerificationCode(code),
      expiresAt: new Date(Date.now() + 10 * 60 * 1000), // 10 минут
    },
  });

  try {
    await sendVerificationEmail(user.email, code);
  } catch (error) {
    console.error('Unable to send verification email', error);
    throw createError({
      statusCode: 503,
      statusMessage: 'Unable to send verification email. Please try again later.',
    });
  }

  return {
    success: true,
    email: user.email,
    verificationRequired: true,
    // В режиме разработки можно выводить код в консоль и отдавать в ответе
    ...(process.env.VERIFICATION_DELIVERY === 'console'
      ? { verificationCode: code }
      : {}),
  };
});
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
<<<<<<< HEAD
  const email = data.email.trim().toLowerCase();

  const existingUser = await prisma.user.findUnique({
    where: { email },
  });

  if (existingUser) {
    throw createError({
      statusCode: 409,
      statusMessage: 'Email address already in use',
    });
  }

  const user = await prisma.user.create({
      data: {
        email,
=======

  const existingUser = await prisma.user.findUnique({
    where: { email: data.email },
  });

  if (existingUser?.emailVerifiedAt) {
    throw createError({
      statusCode: 409,
      statusMessage: 'User already exists',
    });
  }

  const user = existingUser ?? await prisma.user.create({
      data: {
        email: data.email,
>>>>>>> origin/web2
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

  const code = createVerificationCode();

  await prisma.emailVerificationCode.deleteMany({
    where: { userId: user.id },
  });

  await prisma.emailVerificationCode.create({
    data: {
      userId: user.id,
      codeHash: hashVerificationCode(code),
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
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
    ...(process.env.VERIFICATION_DELIVERY === 'console'
      ? { verificationCode: code }
      : {}),
  };
});

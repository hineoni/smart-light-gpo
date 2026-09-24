import { createError, defineEventHandler, readBody } from 'h3';
import { z } from 'zod';
import { signAccessToken, signRefreshToken } from '../../lib/auth';
import { hashVerificationCode } from '../../lib/email_verification';
import { prisma } from '../../lib/prisma';

const schema = z.object({
  email: z.string().email(),
  code: z.string().regex(/^\d{6}$/, 'Code must contain 6 digits'),
});

export default defineEventHandler(async (event) => {
  const data = schema.parse(await readBody(event));
<<<<<<< HEAD
  const email = data.email.trim().toLowerCase();

  const user = await prisma.user.findUnique({
    where: { email },
=======

  const user = await prisma.user.findUnique({
    where: { email: data.email },
>>>>>>> origin/web2
  });

  if (!user) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Invalid verification code',
    });
  }

<<<<<<< HEAD
  if (user.emailVerifiedAt) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Invalid verification code',
    });
  }

=======
>>>>>>> origin/web2
  const verification = await prisma.emailVerificationCode.findFirst({
    where: { userId: user.id },
    orderBy: { createdAt: 'desc' },
  });

  if (!verification || verification.expiresAt < new Date()) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Code expired or not found',
    });
  }

  if (verification.attempts >= 5) {
    throw createError({
      statusCode: 429,
      statusMessage: 'Too many attempts. Request a new code.',
    });
  }

  if (hashVerificationCode(data.code) !== verification.codeHash) {
    await prisma.emailVerificationCode.update({
      where: { id: verification.id },
      data: { attempts: { increment: 1 } },
    });

    throw createError({
      statusCode: 400,
      statusMessage: 'Invalid verification code',
    });
  }

  await prisma.$transaction([
    prisma.user.update({
      where: { id: user.id },
      data: { emailVerifiedAt: new Date() },
    }),
    prisma.emailVerificationCode.delete({
      where: { id: verification.id },
    }),
  ]);

  const payload = { userId: user.id, email: user.email };
  const accessToken = signAccessToken(payload);
  const refreshToken = signRefreshToken(payload);

  await prisma.refreshToken.create({
    data: {
      token: refreshToken,
      userId: user.id,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });

  return { accessToken, refreshToken };
});

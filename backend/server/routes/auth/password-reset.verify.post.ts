import { createError, defineEventHandler, readBody } from 'h3';
import { z } from 'zod';
import { signPasswordResetToken } from '../../lib/auth';
import { hashVerificationCode } from '../../lib/email_verification';
import { prisma } from '../../lib/prisma';

const schema = z.object({
  email: z.string().email(),
  code: z.string().regex(/^\d{6}$/, 'Code must contain 6 digits'),
});

export default defineEventHandler(async (event) => {
  const data = schema.parse(await readBody(event));
  const email = data.email.trim().toLowerCase();
  const user = await prisma.user.findUnique({ where: { email } });

  if (!user || !user.emailVerifiedAt) {
    throw createError({ statusCode: 400, statusMessage: 'Invalid password reset code' });
  }

  const verification = await prisma.emailVerificationCode.findFirst({
    where: { userId: user.id },
    orderBy: { createdAt: 'desc' },
  });

  if (!verification || verification.expiresAt < new Date()) {
    throw createError({ statusCode: 400, statusMessage: 'Code expired or not found' });
  }

  if (verification.attempts >= 5) {
    throw createError({ statusCode: 429, statusMessage: 'Too many attempts. Request a new code.' });
  }

  if (hashVerificationCode(data.code) !== verification.codeHash) {
    await prisma.emailVerificationCode.update({
      where: { id: verification.id },
      data: { attempts: { increment: 1 } },
    });
    throw createError({ statusCode: 400, statusMessage: 'Invalid password reset code' });
  }

  await prisma.emailVerificationCode.delete({ where: { id: verification.id } });
  return { resetToken: signPasswordResetToken({ userId: user.id, email: user.email }) };
});
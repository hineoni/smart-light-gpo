import { createError, defineEventHandler, readBody } from 'h3';
import { z } from 'zod';
import { hashPassword, verifyPasswordResetToken } from '../../lib/auth';
import { prisma } from '../../lib/prisma';

const schema = z.object({
  resetToken: z.string().min(1),
  password: z.string().min(6, 'Password must be at least 6 characters'),
});

export default defineEventHandler(async (event) => {
  const data = schema.parse(await readBody(event));
  let payload;
  try {
    payload = verifyPasswordResetToken(data.resetToken);
  } catch {
    throw createError({ statusCode: 400, statusMessage: 'Invalid or expired reset session' });
  }

  const user = await prisma.user.findUnique({ where: { id: payload.userId } });
  if (!user || user.email !== payload.email) {
    throw createError({ statusCode: 400, statusMessage: 'Invalid or expired reset session' });
  }

  await prisma.$transaction([
    prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: await hashPassword(data.password) },
    }),
    prisma.refreshToken.deleteMany({ where: { userId: user.id } }),
  ]);

  return { success: true };
});
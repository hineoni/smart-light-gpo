import { createError, defineEventHandler, readBody } from 'h3';
import { z } from 'zod';
import { createVerificationCode, hashVerificationCode } from '../../lib/email_verification';
import { sendPasswordResetEmail } from '../../lib/mailer';
import { prisma } from '../../lib/prisma';

const schema = z.object({ email: z.string().email() });

export default defineEventHandler(async (event) => {
  const { email: rawEmail } = schema.parse(await readBody(event));
  const email = rawEmail.trim().toLowerCase();
  const user = await prisma.user.findUnique({ where: { email } });

  if (!user || !user.emailVerifiedAt) {
    return { success: true };
  }

  const code = createVerificationCode();
  await prisma.emailVerificationCode.deleteMany({ where: { userId: user.id } });
  await prisma.emailVerificationCode.create({
    data: {
      userId: user.id,
      codeHash: hashVerificationCode(code),
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
    },
  });

  try {
    await sendPasswordResetEmail(user.email, code);
  } catch (error) {
    console.error('Unable to send password reset email', error);
    throw createError({
      statusCode: 503,
      statusMessage: 'Unable to send password reset email. Please try again later.',
    });
  }

  return {
    success: true,
    ...(process.env.VERIFICATION_DELIVERY === 'console' ? { verificationCode: code } : {}),
  };
});
import { createError, defineEventHandler, readBody } from 'h3';
import { z } from 'zod';
import {
  signAccessToken,
  signRefreshToken,
  verifyPassword,
} from '../../lib/auth';
import { prisma } from '../../lib/prisma';

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(6, 'Password must be at least 6 characters'),
});

export default defineEventHandler(async (event) => {
  const data = schema.parse(await readBody(event));

  const user = await prisma.user.findUnique({
    where: { email: data.email },
  });

  if (!user || !(await verifyPassword(data.password, user.passwordHash))) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Invalid credentials',
    });
  }

  const payload = {
    userId: user.id,
    email: user.email,
  };
  const accessToken = signAccessToken(payload);
  const refreshToken = signRefreshToken(payload);

  await prisma.refreshToken.create({
    data: {
      token: refreshToken,
      userId: user.id,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });

  return {
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
    },
    accessToken,
    refreshToken,
  };
});

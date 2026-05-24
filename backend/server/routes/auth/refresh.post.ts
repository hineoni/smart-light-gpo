import { createError, defineEventHandler, readBody } from 'h3';
import { z } from 'zod';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from '../../lib/auth';
import { prisma } from '../../lib/prisma';

const schema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export default defineEventHandler(async (event) => {
  const data = schema.parse(await readBody(event));

  const existingToken = await prisma.refreshToken.findUnique({
    where: { token: data.refreshToken },
  });

  if (
    !existingToken ||
    existingToken.revokedAt ||
    existingToken.expiresAt < new Date()
  ) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Invalid refresh token',
    });
  }

  let payload: { userId: string; email: string };
  try {
    payload = verifyRefreshToken(data.refreshToken);
  } catch {
    throw createError({
      statusCode: 401,
      statusMessage: 'Invalid refresh token',
    });
  }

  await prisma.refreshToken.update({
    where: { token: data.refreshToken },
    data: { revokedAt: new Date() },
  });

  const accessToken = signAccessToken(payload);
  const refreshToken = signRefreshToken(payload);

  await prisma.refreshToken.create({
    data: {
      token: refreshToken,
      userId: payload.userId,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });

  return {
    accessToken,
    refreshToken,
  };
});

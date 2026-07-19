import { createError, defineEventHandler, readBody } from 'h3';
import { z } from 'zod';
import { hashPassword } from '../../lib/auth';
import { prisma } from '../../lib/prisma';

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(6, 'Password must be at least 6 characters'),
  name: z.string().min(2).optional(),
});

export default defineEventHandler(async (event) => {
  const data = schema.parse(await readBody(event));

  const existingUser = await prisma.user.findUnique({
    where: { email: data.email },
  });

  if (existingUser) {
    throw createError({
      statusCode: 409,
      statusMessage: 'User already exists',
    });
  }

  const user = await prisma.user.create({
    data: {
      email: data.email,
      passwordHash: await hashPassword(data.password),
      name: data.name,
    },
    select: {
      id: true,
      email: true,
      name: true,
      createdAt: true,
    },
  });

  return {
    success: true,
    user,
  };
});

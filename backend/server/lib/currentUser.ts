import { createError, type H3Event } from 'h3';

export function requireUserId(event: H3Event) {
  const userId = event.context.user?.userId;

  if (!userId) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Unauthorized',
    });
  }

  return userId;
}

import { createError, defineEventHandler, getHeader } from 'h3';
import { verifyAccessToken } from '../lib/auth';

const publicPrefixes = [
  '/_',
  '/auth/register',
  '/auth/login',
  '/auth/refresh',
  '/auth/verify',
  '/health',
  '/_openapi.json',
  '/_scalar',
  '/_ws',
];

export default defineEventHandler((event) => {
  const path = event.path || event.node.req.url || '';

  if (path === '/' || publicPrefixes.some((prefix) => path.startsWith(prefix))) {
    return;
  }

  const authHeader = getHeader(event, 'authorization');

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Unauthorized',
    });
  }

  const token = authHeader.slice('Bearer '.length);

  try {
    event.context.user = verifyAccessToken(token);
  } catch {
    throw createError({
      statusCode: 401,
      statusMessage: 'Invalid or expired token',
    });
  }
});

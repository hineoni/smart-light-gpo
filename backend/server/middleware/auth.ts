import { createError, defineEventHandler, getHeader, getMethod, sendNoContent } from 'h3';
import { verifyAccessToken } from '../lib/auth';

const publicPrefixes = [
  '/_',
  '/auth/register',
  '/auth/login',
  '/auth/refresh',
  '/auth/verify',

  '/auth/password-reset/',


  '/health',
  '/_openapi.json',
  '/_scalar',
  '/_ws',
];

export default defineEventHandler((event) => {
  const path = event.path || event.node.req.url || '';

  const origin = getHeader(event, 'origin');
  const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);

  if (origin && allowedOrigins.includes(origin)) {
    event.node.res.setHeader('Access-Control-Allow-Origin', origin);
    event.node.res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
    event.node.res.setHeader('Access-Control-Allow-Headers', 'Authorization,Content-Type');
    event.node.res.setHeader('Vary', 'Origin');
  }

  if (getMethod(event) === 'OPTIONS') {
    return sendNoContent(event);
  }

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

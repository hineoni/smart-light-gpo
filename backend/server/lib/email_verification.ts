import { createHash, randomInt } from 'node:crypto';

function getSecret() {
  const secret = process.env.EMAIL_CODE_SECRET;

  if (!secret) {
    throw new Error('EMAIL_CODE_SECRET is not configured');
  }

  return secret;
}

export function createVerificationCode() {
  return randomInt(100000, 1000000).toString();
}

export function hashVerificationCode(code: string) {
  return createHash('sha256')
    .update(`${code}:${getSecret()}`)
    .digest('hex');
}

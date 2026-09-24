import bcrypt from 'bcryptjs';
import jwt, { type SignOptions } from 'jsonwebtoken';

const accessSecret = process.env.JWT_ACCESS_SECRET || 'access_secret';
const refreshSecret = process.env.JWT_REFRESH_SECRET || 'refresh_secret';

const accessExpires = (process.env.JWT_ACCESS_EXPIRES ||
  '15m') as SignOptions['expiresIn'];
const refreshExpires = (process.env.JWT_REFRESH_EXPIRES ||
  '30d') as SignOptions['expiresIn'];
<<<<<<< HEAD
const passwordResetExpires = '10m' as SignOptions['expiresIn'];
=======
>>>>>>> origin/web2

export type JwtPayload = {
  userId: string;
  email: string;
};

<<<<<<< HEAD
type PasswordResetPayload = JwtPayload & { purpose: 'password_reset' };

=======
>>>>>>> origin/web2
export function hashPassword(password: string) {
  return bcrypt.hash(password, 10);
}

export function verifyPassword(password: string, hash: string) {
  return bcrypt.compare(password, hash);
}

export function signAccessToken(payload: JwtPayload) {
  return jwt.sign(payload, accessSecret, { expiresIn: accessExpires });
}

export function signRefreshToken(payload: JwtPayload) {
  return jwt.sign(payload, refreshSecret, { expiresIn: refreshExpires });
}

<<<<<<< HEAD
export function signPasswordResetToken(payload: JwtPayload) {
  return jwt.sign(
    { ...payload, purpose: 'password_reset' } satisfies PasswordResetPayload,
    accessSecret,
    { expiresIn: passwordResetExpires },
  );
}

export function verifyPasswordResetToken(token: string) {
  const payload = jwt.verify(token, accessSecret) as Partial<PasswordResetPayload>;
  if (payload.purpose !== 'password_reset' || !payload.userId || !payload.email) {
    throw new Error('Invalid password reset token');
  }
  return { userId: payload.userId, email: payload.email };
}

=======
>>>>>>> origin/web2
export function verifyAccessToken(token: string) {
  const payload = jwt.verify(token, accessSecret) as JwtPayload;
  return { userId: payload.userId, email: payload.email };
}

export function verifyRefreshToken(token: string) {
  const payload = jwt.verify(token, refreshSecret) as JwtPayload;
  return { userId: payload.userId, email: payload.email };
}

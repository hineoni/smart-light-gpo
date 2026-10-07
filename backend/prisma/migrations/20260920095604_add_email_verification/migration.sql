-- AlterTable
ALTER TABLE "Device" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "LightScene" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "emailVerifiedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "Zone" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- CreateTable
CREATE TABLE "emailVerificatinCode" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "emailVerificatinCode_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "emailVerificatinCode_userId_idx" ON "emailVerificatinCode"("userId");

-- AddForeignKey
ALTER TABLE "emailVerificatinCode" ADD CONSTRAINT "emailVerificatinCode_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

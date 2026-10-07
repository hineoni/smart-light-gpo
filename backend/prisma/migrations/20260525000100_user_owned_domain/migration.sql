CREATE TABLE "Device" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "ip" TEXT NOT NULL DEFAULT 'unknown',
    "status" TEXT NOT NULL DEFAULT 'disconnected',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "servo1Angle" DOUBLE PRECISION,
    "servo2Angle" DOUBLE PRECISION,
    "brightness" DOUBLE PRECISION,
    "colorR" INTEGER,
    "colorG" INTEGER,
    "colorB" INTEGER,
    "lastHeartbeat" TIMESTAMP(3),
    "uwbReady" BOOLEAN,
    "uwbRangeCount" INTEGER,
    "uwbUartBytes" INTEGER,
    "uwbDiscardedBytes" INTEGER,
    "uwbParsedFrames" INTEGER,
    "uwbInvalidFrames" INTEGER,
    "uwbParsedLines" INTEGER,
    "uwbInvalidLines" INTEGER,
    "uwbLastByteAtMs" INTEGER,
    "uwbLastRxHex" TEXT,
    "uwbAutoConfig" BOOLEAN,
    "uwbRole" INTEGER,
    "uwbPid" INTEGER,
    "uwbPeriod" INTEGER,
    "uwbLocalAddress" INTEGER,
    "uwbPeer0Address" INTEGER,
    "userId" TEXT,
    "zoneId" TEXT,

    CONSTRAINT "Device_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Zone" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "x" DOUBLE PRECISION NOT NULL DEFAULT 0.5,
    "y" DOUBLE PRECISION NOT NULL DEFAULT 0.5,
    "heightM" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Zone_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "LightScene" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "zoneId" TEXT,
    "positioningSnapshot" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LightScene_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "LightSceneDeviceState" (
    "id" TEXT NOT NULL,
    "sceneId" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "zoneId" TEXT,
    "brightness" DOUBLE PRECISION NOT NULL DEFAULT 255,
    "colorR" INTEGER NOT NULL DEFAULT 255,
    "colorG" INTEGER NOT NULL DEFAULT 255,
    "colorB" INTEGER NOT NULL DEFAULT 255,
    "servo1Angle" DOUBLE PRECISION NOT NULL DEFAULT 90,
    "servo2Angle" DOUBLE PRECISION NOT NULL DEFAULT 90,
    "uwbLocalAddress" INTEGER,
    "x" DOUBLE PRECISION,
    "y" DOUBLE PRECISION,
    "heightM" DOUBLE PRECISION,

    CONSTRAINT "LightSceneDeviceState_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "Device_uwbLocalAddress_key" ON "Device"("uwbLocalAddress");
CREATE UNIQUE INDEX "Zone_userId_id_key" ON "Zone"("userId", "id");
CREATE INDEX "LightSceneDeviceState_sceneId_idx" ON "LightSceneDeviceState"("sceneId");
CREATE INDEX "LightSceneDeviceState_deviceId_idx" ON "LightSceneDeviceState"("deviceId");

ALTER TABLE "Device" ADD CONSTRAINT "Device_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "Device" ADD CONSTRAINT "Device_zoneId_fkey" FOREIGN KEY ("zoneId") REFERENCES "Zone"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "Zone" ADD CONSTRAINT "Zone_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "LightScene" ADD CONSTRAINT "LightScene_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "LightScene" ADD CONSTRAINT "LightScene_zoneId_fkey" FOREIGN KEY ("zoneId") REFERENCES "Zone"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "LightSceneDeviceState" ADD CONSTRAINT "LightSceneDeviceState_sceneId_fkey" FOREIGN KEY ("sceneId") REFERENCES "LightScene"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "LightSceneDeviceState" ADD CONSTRAINT "LightSceneDeviceState_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

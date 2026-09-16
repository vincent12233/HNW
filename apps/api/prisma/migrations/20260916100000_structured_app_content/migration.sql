-- Phase 11B: additive structured app content (no DROP / rename of AppContentEntry)

-- AlterTable: featured surface flags on instruments (reuse catalog; no second stock table)
ALTER TABLE "instruments" ADD COLUMN "featuredHome" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "instruments" ADD COLUMN "featuredMarkets" BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX "instruments_featuredHome_displayOrder_idx" ON "instruments"("featuredHome", "displayOrder");
CREATE INDEX "instruments_featuredMarkets_displayOrder_idx" ON "instruments"("featuredMarkets", "displayOrder");

-- CreateEnum
CREATE TYPE "AnnouncementType" AS ENUM ('GENERAL', 'MAINTENANCE', 'IMPORTANT', 'MARKET_NOTICE');

-- CreateEnum
CREATE TYPE "AppClientPlatform" AS ENUM ('ANDROID', 'IOS', 'WEB');

-- CreateTable
CREATE TABLE "insight_articles" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "locale" TEXT NOT NULL DEFAULT 'en',
    "title" TEXT NOT NULL,
    "summary" TEXT,
    "body" TEXT NOT NULL,
    "imageUrl" TEXT,
    "isPublished" BOOLEAN NOT NULL DEFAULT false,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdById" TEXT,
    "updatedById" TEXT,
    CONSTRAINT "insight_articles_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "insight_articles_slug_locale_key" ON "insight_articles"("slug", "locale");
CREATE INDEX "insight_articles_isPublished_sortOrder_idx" ON "insight_articles"("isPublished", "sortOrder");
CREATE INDEX "insight_articles_locale_isPublished_idx" ON "insight_articles"("locale", "isPublished");

ALTER TABLE "insight_articles" ADD CONSTRAINT "insight_articles_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "insight_articles" ADD CONSTRAINT "insight_articles_updatedById_fkey" FOREIGN KEY ("updatedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "announcements" (
    "id" TEXT NOT NULL,
    "locale" TEXT NOT NULL DEFAULT 'en',
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "type" "AnnouncementType" NOT NULL DEFAULT 'GENERAL',
    "isPublished" BOOLEAN NOT NULL DEFAULT false,
    "priority" INTEGER NOT NULL DEFAULT 0,
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdById" TEXT,
    "updatedById" TEXT,
    CONSTRAINT "announcements_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "announcements_isPublished_sortOrder_idx" ON "announcements"("isPublished", "sortOrder");
CREATE INDEX "announcements_locale_isPublished_idx" ON "announcements"("locale", "isPublished");
CREATE INDEX "announcements_startsAt_endsAt_idx" ON "announcements"("startsAt", "endsAt");

ALTER TABLE "announcements" ADD CONSTRAINT "announcements_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "announcements" ADD CONSTRAINT "announcements_updatedById_fkey" FOREIGN KEY ("updatedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "app_client_settings" (
    "id" TEXT NOT NULL,
    "platform" "AppClientPlatform" NOT NULL,
    "minVersion" TEXT NOT NULL DEFAULT '0.0.0',
    "latestVersion" TEXT NOT NULL DEFAULT '0.0.0',
    "forceUpdate" BOOLEAN NOT NULL DEFAULT false,
    "maintenanceMode" BOOLEAN NOT NULL DEFAULT false,
    "maintenanceMessage" TEXT,
    "supportUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "updatedById" TEXT,
    CONSTRAINT "app_client_settings_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "app_client_settings_platform_key" ON "app_client_settings"("platform");

ALTER TABLE "app_client_settings" ADD CONSTRAINT "app_client_settings_updatedById_fkey" FOREIGN KEY ("updatedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

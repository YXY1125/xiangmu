-- App-owned PostgreSQL migration derived from frozen AppSpec. Never modifies platform tables.
BEGIN;
CREATE TABLE IF NOT EXISTS "thwkb_user_profiles" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "userId" text NOT NULL,
  "nickname" text NOT NULL,
  "avatarAssetId" uuid,
  "bio" text,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_user_profiles_q0" ON "thwkb_user_profiles" ("tenantId", "appId", "userId");
CREATE TABLE IF NOT EXISTS "thwkb_categories" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "scope" text NOT NULL CHECK ("scope" IN ('character', 'knowledge', 'material', 'artwork')),
  "name" text NOT NULL,
  "sortOrder" integer NOT NULL,
  "status" text NOT NULL CHECK ("status" IN ('draft', 'published', 'offline')),
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_categories_q0" ON "thwkb_categories" ("tenantId", "appId", "scope", "status");
CREATE INDEX IF NOT EXISTS "thwkb_categories_q1" ON "thwkb_categories" ("tenantId", "appId", "scope", "name");
CREATE TABLE IF NOT EXISTS "thwkb_characters" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "categoryId" uuid NOT NULL,
  "name" text NOT NULL,
  "series" text NOT NULL,
  "rolePosition" text NOT NULL,
  "appearance" text NOT NULL,
  "palette" jsonb NOT NULL,
  "costume" text NOT NULL,
  "personality" text NOT NULL,
  "culturalInspiration" text NOT NULL,
  "originalStory" text NOT NULL,
  "historicalSourceIds" jsonb NOT NULL,
  "heroAssetId" uuid NOT NULL,
  "status" text NOT NULL CHECK ("status" IN ('draft', 'reviewing', 'published', 'offline')),
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_characters_q0" ON "thwkb_characters" ("tenantId", "appId", "categoryId", "status");
CREATE INDEX IF NOT EXISTS "thwkb_characters_q1" ON "thwkb_characters" ("tenantId", "appId", "series", "status");
CREATE TABLE IF NOT EXISTS "thwkb_topics" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "title" text NOT NULL,
  "summary" text NOT NULL,
  "coverAssetId" uuid NOT NULL,
  "contentRefs" jsonb NOT NULL,
  "status" text NOT NULL CHECK ("status" IN ('draft', 'published', 'offline')),
  "publishAt" timestamptz,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_topics_q0" ON "thwkb_topics" ("tenantId", "appId", "status", "publishAt");
CREATE TABLE IF NOT EXISTS "thwkb_knowledge_articles" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "categoryId" uuid NOT NULL,
  "title" text NOT NULL,
  "summary" text NOT NULL,
  "body" text NOT NULL,
  "coverAssetId" uuid NOT NULL,
  "sourceRecords" jsonb NOT NULL,
  "factCheckStatus" text NOT NULL CHECK ("factCheckStatus" IN ('pending', 'verified', 'rejected')),
  "status" text NOT NULL CHECK ("status" IN ('draft', 'reviewing', 'published', 'offline')),
  "publishedAt" timestamptz,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_knowledge_articles_q0" ON "thwkb_knowledge_articles" ("tenantId", "appId", "categoryId", "status");
CREATE INDEX IF NOT EXISTS "thwkb_knowledge_articles_q1" ON "thwkb_knowledge_articles" ("tenantId", "appId", "factCheckStatus", "status");
CREATE TABLE IF NOT EXISTS "thwkb_materials" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "categoryId" uuid NOT NULL,
  "kind" text NOT NULL CHECK ("kind" IN ('character', 'background', 'sticker', 'seal', 'font', 'frame')),
  "name" text NOT NULL,
  "assetId" uuid NOT NULL,
  "canvasMetadata" jsonb NOT NULL,
  "copyrightOwner" text NOT NULL,
  "sourceType" text NOT NULL CHECK ("sourceType" IN ('original', 'licensed')),
  "licenseRecord" jsonb NOT NULL,
  "status" text NOT NULL CHECK ("status" IN ('draft', 'rights_pending', 'reviewing', 'published', 'offline')),
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_materials_q0" ON "thwkb_materials" ("tenantId", "appId", "kind", "status");
CREATE INDEX IF NOT EXISTS "thwkb_materials_q1" ON "thwkb_materials" ("tenantId", "appId", "categoryId", "status");
CREATE TABLE IF NOT EXISTS "thwkb_templates" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "name" text NOT NULL,
  "coverAssetId" uuid NOT NULL,
  "aspectRatio" text NOT NULL,
  "canvasWidth" integer NOT NULL,
  "canvasHeight" integer NOT NULL,
  "baseLayers" jsonb NOT NULL,
  "allowedMaterialKinds" jsonb NOT NULL,
  "status" text NOT NULL CHECK ("status" IN ('draft', 'rights_pending', 'published', 'offline')),
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_templates_q0" ON "thwkb_templates" ("tenantId", "appId", "status");
CREATE TABLE IF NOT EXISTS "thwkb_creations" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "userId" text NOT NULL,
  "templateId" uuid NOT NULL,
  "title" text NOT NULL,
  "status" text NOT NULL CHECK ("status" IN ('draft', 'completed', 'archived')),
  "canvasState" jsonb NOT NULL,
  "previewAssetId" uuid,
  "revision" integer NOT NULL,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_creations_q0" ON "thwkb_creations" ("tenantId", "appId", "userId", "status", "updatedAt");
CREATE INDEX IF NOT EXISTS "thwkb_creations_q1" ON "thwkb_creations" ("tenantId", "appId", "userId", "id");
CREATE TABLE IF NOT EXISTS "thwkb_artworks" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "ownerUserId" text,
  "creationId" uuid,
  "sourceType" text NOT NULL CHECK ("sourceType" IN ('official', 'user_original')),
  "title" text NOT NULL,
  "description" text NOT NULL,
  "coverAssetId" uuid NOT NULL,
  "copyrightDeclaration" text NOT NULL,
  "rightsEvidence" jsonb NOT NULL,
  "visibility" text NOT NULL CHECK ("visibility" IN ('private', 'public')),
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_artworks_q0" ON "thwkb_artworks" ("tenantId", "appId", "ownerUserId", "createdAt");
CREATE INDEX IF NOT EXISTS "thwkb_artworks_q1" ON "thwkb_artworks" ("tenantId", "appId", "sourceType", "visibility");
CREATE TABLE IF NOT EXISTS "thwkb_publications" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "userId" text NOT NULL,
  "artworkId" uuid NOT NULL,
  "status" text NOT NULL CHECK ("status" IN ('draft', 'submitted', 'approved', 'rejected', 'offline')),
  "reviewReason" text,
  "submittedAt" timestamptz,
  "reviewedAt" timestamptz,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_publications_q0" ON "thwkb_publications" ("tenantId", "appId", "status", "reviewedAt");
CREATE INDEX IF NOT EXISTS "thwkb_publications_q1" ON "thwkb_publications" ("tenantId", "appId", "userId", "status");
CREATE TABLE IF NOT EXISTS "thwkb_favorites" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "userId" text NOT NULL,
  "targetType" text NOT NULL CHECK ("targetType" IN ('character', 'knowledge', 'artwork')),
  "targetId" uuid NOT NULL,
  "createdAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_favorites_q0" ON "thwkb_favorites" ("tenantId", "appId", "userId", "targetType", "targetId");
CREATE INDEX IF NOT EXISTS "thwkb_favorites_q1" ON "thwkb_favorites" ("tenantId", "appId", "userId", "createdAt");
CREATE TABLE IF NOT EXISTS "thwkb_likes" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "userId" text NOT NULL,
  "artworkId" uuid NOT NULL,
  "createdAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_likes_q0" ON "thwkb_likes" ("tenantId", "appId", "userId", "artworkId");
CREATE INDEX IF NOT EXISTS "thwkb_likes_q1" ON "thwkb_likes" ("tenantId", "appId", "artworkId");
CREATE TABLE IF NOT EXISTS "thwkb_browse_history" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "userId" text NOT NULL,
  "targetType" text NOT NULL CHECK ("targetType" IN ('character', 'knowledge', 'artwork')),
  "targetId" uuid NOT NULL,
  "viewCount" integer NOT NULL,
  "lastViewedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_browse_history_q0" ON "thwkb_browse_history" ("tenantId", "appId", "userId", "targetType", "targetId");
CREATE INDEX IF NOT EXISTS "thwkb_browse_history_q1" ON "thwkb_browse_history" ("tenantId", "appId", "userId", "lastViewedAt");
CREATE TABLE IF NOT EXISTS "thwkb_reports" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "userId" text NOT NULL,
  "artworkId" uuid NOT NULL,
  "reasonCode" text NOT NULL,
  "description" text,
  "status" text NOT NULL CHECK ("status" IN ('submitted', 'reviewing', 'resolved', 'dismissed')),
  "resolution" text,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_reports_q0" ON "thwkb_reports" ("tenantId", "appId", "status", "createdAt");
CREATE INDEX IF NOT EXISTS "thwkb_reports_q1" ON "thwkb_reports" ("tenantId", "appId", "userId", "artworkId");
CREATE TABLE IF NOT EXISTS "thwkb_notifications" (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "userId" text NOT NULL,
  "kind" text NOT NULL CHECK ("kind" IN ('review', 'interaction', 'system')),
  "title" text NOT NULL,
  "body" text NOT NULL,
  "targetRoute" text,
  "readAt" timestamptz,
  "createdAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId", "appId", "id")
);
CREATE INDEX IF NOT EXISTS "thwkb_notifications_q0" ON "thwkb_notifications" ("tenantId", "appId", "userId", "readAt", "createdAt");
ALTER TABLE "thwkb_characters" ADD CONSTRAINT "thwkb_characters_categoryId_fk" FOREIGN KEY ("tenantId", "appId", "categoryId") REFERENCES "thwkb_categories" ("tenantId", "appId", "id") DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE "thwkb_knowledge_articles" ADD CONSTRAINT "thwkb_knowledge_articles_categoryId_fk" FOREIGN KEY ("tenantId", "appId", "categoryId") REFERENCES "thwkb_categories" ("tenantId", "appId", "id") DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE "thwkb_materials" ADD CONSTRAINT "thwkb_materials_categoryId_fk" FOREIGN KEY ("tenantId", "appId", "categoryId") REFERENCES "thwkb_categories" ("tenantId", "appId", "id") DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE "thwkb_creations" ADD CONSTRAINT "thwkb_creations_templateId_fk" FOREIGN KEY ("tenantId", "appId", "templateId") REFERENCES "thwkb_templates" ("tenantId", "appId", "id") DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE "thwkb_artworks" ADD CONSTRAINT "thwkb_artworks_creationId_fk" FOREIGN KEY ("tenantId", "appId", "creationId") REFERENCES "thwkb_creations" ("tenantId", "appId", "id") DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE "thwkb_publications" ADD CONSTRAINT "thwkb_publications_artworkId_fk" FOREIGN KEY ("tenantId", "appId", "artworkId") REFERENCES "thwkb_artworks" ("tenantId", "appId", "id") DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE "thwkb_likes" ADD CONSTRAINT "thwkb_likes_artworkId_fk" FOREIGN KEY ("tenantId", "appId", "artworkId") REFERENCES "thwkb_artworks" ("tenantId", "appId", "id") DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE "thwkb_reports" ADD CONSTRAINT "thwkb_reports_artworkId_fk" FOREIGN KEY ("tenantId", "appId", "artworkId") REFERENCES "thwkb_artworks" ("tenantId", "appId", "id") DEFERRABLE INITIALLY DEFERRED;
CREATE UNIQUE INDEX IF NOT EXISTS "thwkb_user_profiles_business_unique" ON "thwkb_user_profiles" ("tenantId", "appId", "userId");
CREATE UNIQUE INDEX IF NOT EXISTS "thwkb_favorites_business_unique" ON "thwkb_favorites" ("tenantId", "appId", "userId", "targetType", "targetId");
CREATE UNIQUE INDEX IF NOT EXISTS "thwkb_likes_business_unique" ON "thwkb_likes" ("tenantId", "appId", "userId", "artworkId");
CREATE UNIQUE INDEX IF NOT EXISTS "thwkb_browse_history_business_unique" ON "thwkb_browse_history" ("tenantId", "appId", "userId", "targetType", "targetId");
CREATE TABLE IF NOT EXISTS thwkb_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());
INSERT INTO thwkb_migrations(version) VALUES ('001');
COMMIT;

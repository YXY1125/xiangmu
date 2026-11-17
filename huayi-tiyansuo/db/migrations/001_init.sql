-- 花艺体验所应用级参考迁移。未经单独数据库/Schema 变更授权不得执行。
-- 生产当前使用 saas26 租户运行时 JSON；本文件定义未来关系型持久化的隔离契约。
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS hytys_flower_categories (
  id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, app_id TEXT NOT NULL, code TEXT NOT NULL,
  name TEXT NOT NULL, sort_order INT NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'published',
  UNIQUE (tenant_id, app_id, code)
);
CREATE TABLE IF NOT EXISTS hytys_flower_materials (
  id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, app_id TEXT NOT NULL, category_id TEXT NOT NULL,
  name TEXT NOT NULL, aliases JSONB NOT NULL DEFAULT '[]', image_key TEXT NOT NULL,
  family_genus TEXT, flower_language TEXT, culture_meaning TEXT, colors JSONB NOT NULL DEFAULT '[]',
  flowering_season TEXT, environment TEXT, care_guide TEXT, freshness_tips TEXT,
  pairing_advice TEXT, scenes JSONB NOT NULL DEFAULT '[]', editor_asset_key TEXT,
  status TEXT NOT NULL DEFAULT 'published', updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS hytys_material_scope_idx ON hytys_flower_materials(tenant_id, app_id, category_id, status);

CREATE TABLE IF NOT EXISTS hytys_flower_tutorials (
  id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, app_id TEXT NOT NULL, category TEXT NOT NULL,
  title TEXT NOT NULL, cover_key TEXT NOT NULL, introduction TEXT NOT NULL, difficulty TEXT NOT NULL,
  duration_minutes INT NOT NULL, material_ids JSONB NOT NULL DEFAULT '[]', tools JSONB NOT NULL DEFAULT '[]',
  completion_rule JSONB NOT NULL DEFAULT '{}', status TEXT NOT NULL DEFAULT 'published'
);
CREATE TABLE IF NOT EXISTS hytys_tutorial_steps (
  id TEXT PRIMARY KEY, tutorial_id TEXT NOT NULL, step_no INT NOT NULL, title TEXT NOT NULL,
  image_key TEXT NOT NULL, instruction TEXT NOT NULL, tip TEXT, UNIQUE(tutorial_id, step_no)
);
CREATE TABLE IF NOT EXISTS hytys_user_learning (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id TEXT NOT NULL, app_id TEXT NOT NULL,
  user_id TEXT NOT NULL, tutorial_id TEXT NOT NULL, current_step INT NOT NULL DEFAULT 0,
  completed BOOLEAN NOT NULL DEFAULT FALSE, updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(tenant_id, app_id, user_id, tutorial_id)
);

CREATE TABLE IF NOT EXISTS hytys_flower_works (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id TEXT NOT NULL, app_id TEXT NOT NULL,
  user_id TEXT NOT NULL, author_name TEXT NOT NULL, title TEXT NOT NULL, theme_name TEXT,
  challenge_id TEXT, canvas_config JSONB NOT NULL, material_ids JSONB NOT NULL DEFAULT '[]',
  visibility TEXT NOT NULL DEFAULT 'private', status TEXT NOT NULL DEFAULT 'draft', version INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), published_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS hytys_work_owner_idx ON hytys_flower_works(tenant_id, app_id, user_id, status);
CREATE TABLE IF NOT EXISTS hytys_work_materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), work_id UUID NOT NULL, material_id TEXT NOT NULL,
  object_id TEXT NOT NULL, x DOUBLE PRECISION NOT NULL, y DOUBLE PRECISION NOT NULL,
  scale DOUBLE PRECISION NOT NULL, rotation DOUBLE PRECISION NOT NULL, z_index INT NOT NULL,
  UNIQUE(work_id, object_id)
);
CREATE TABLE IF NOT EXISTS hytys_work_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id TEXT NOT NULL, app_id TEXT NOT NULL,
  user_id TEXT NOT NULL, work_id UUID NOT NULL, type TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(tenant_id, app_id, user_id, work_id, type)
);

CREATE TABLE IF NOT EXISTS hytys_flower_events (
  id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, app_id TEXT NOT NULL, title TEXT NOT NULL,
  cover_key TEXT NOT NULL, introduction TEXT NOT NULL, theme TEXT NOT NULL,
  starts_at TIMESTAMPTZ NOT NULL, ends_at TIMESTAMPTZ NOT NULL, rules TEXT NOT NULL,
  recommended_material_ids JSONB NOT NULL DEFAULT '[]', completion_rule JSONB NOT NULL DEFAULT '{}',
  reward TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'published'
);
CREATE TABLE IF NOT EXISTS hytys_event_tasks (
  id TEXT PRIMARY KEY, event_id TEXT NOT NULL, title TEXT NOT NULL, requirement TEXT NOT NULL,
  condition JSONB NOT NULL DEFAULT '{}', sort_order INT NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS hytys_event_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id TEXT NOT NULL, app_id TEXT NOT NULL,
  user_id TEXT NOT NULL, event_id TEXT NOT NULL, work_id UUID NOT NULL, status TEXT NOT NULL DEFAULT 'submitted',
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(tenant_id, app_id, user_id, event_id, work_id)
);

CREATE TABLE IF NOT EXISTS hytys_achievement_rules (
  id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, app_id TEXT NOT NULL, title TEXT NOT NULL,
  description TEXT NOT NULL, category TEXT NOT NULL, metric TEXT NOT NULL, target INT NOT NULL,
  status TEXT NOT NULL DEFAULT 'published'
);
CREATE TABLE IF NOT EXISTS hytys_user_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id TEXT NOT NULL, app_id TEXT NOT NULL,
  user_id TEXT NOT NULL, achievement_code TEXT NOT NULL, progress INT NOT NULL DEFAULT 0,
  target INT NOT NULL, unlocked BOOLEAN NOT NULL DEFAULT FALSE, unlocked_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(tenant_id, app_id, user_id, achievement_code)
);
CREATE TABLE IF NOT EXISTS hytys_user_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id TEXT NOT NULL, app_id TEXT NOT NULL,
  user_id TEXT NOT NULL, target_type TEXT NOT NULL, target_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(tenant_id, app_id, user_id, target_type, target_id)
);
CREATE TABLE IF NOT EXISTS hytys_home_banners (
  id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, app_id TEXT NOT NULL, title TEXT NOT NULL,
  description TEXT NOT NULL, image_key TEXT NOT NULL, target_type TEXT NOT NULL, target_id TEXT,
  sort_order INT NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'published'
);

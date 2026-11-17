-- 咖啡研习间项目级 PostgreSQL 迁移草案。
-- 未自动应用到共享或生产数据库；执行必须走 V5.0 数据库变更审批。
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS coffee_public_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id VARCHAR(64) NOT NULL,
  content_type VARCHAR(32) NOT NULL,
  category VARCHAR(64) NOT NULL,
  title VARCHAR(160) NOT NULL,
  summary TEXT NOT NULL,
  body JSONB NOT NULL DEFAULT '{}'::jsonb,
  source_note TEXT,
  status VARCHAR(24) NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,
  UNIQUE (tenant_id, content_type, title)
);

CREATE TABLE IF NOT EXISTS coffee_user_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id VARCHAR(64) NOT NULL,
  user_id UUID NOT NULL,
  record_type VARCHAR(32) NOT NULL,
  public_content_id UUID REFERENCES coffee_public_content(id),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  version_no INTEGER NOT NULL DEFAULT 1 CHECK (version_no > 0),
  parent_version_id UUID REFERENCES coffee_user_records(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS coffee_user_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id VARCHAR(64) NOT NULL,
  user_id UUID NOT NULL,
  action_type VARCHAR(32) NOT NULL,
  target_type VARCHAR(32) NOT NULL,
  target_id UUID NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,
  UNIQUE (tenant_id, user_id, action_type, target_type, target_id)
);

CREATE TABLE IF NOT EXISTS coffee_consents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id VARCHAR(64) NOT NULL,
  user_id UUID NOT NULL,
  agreement_version VARCHAR(32) NOT NULL,
  privacy_version VARCHAR(32) NOT NULL,
  consented_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, user_id, agreement_version, privacy_version)
);

CREATE INDEX IF NOT EXISTS idx_coffee_public_lookup
  ON coffee_public_content(tenant_id, content_type, category, status) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_coffee_record_owner
  ON coffee_user_records(tenant_id, user_id, record_type, created_at DESC) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_coffee_action_owner
  ON coffee_user_actions(tenant_id, user_id, action_type, created_at DESC) WHERE archived_at IS NULL;

-- 所有私有数据查询必须同时绑定服务端认证会话导出的 tenant_id 与 user_id。
-- 业务记录只允许新增版本或设置 archived_at，禁止 DELETE。

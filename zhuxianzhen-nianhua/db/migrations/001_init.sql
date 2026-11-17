-- 朱仙镇年画专属业务表定义。仅作为版本化迁移产物；尚未执行到共享数据库。
CREATE TABLE IF NOT EXISTS zxznh_content (
  id VARCHAR(64) PRIMARY KEY,
  tenant_id VARCHAR(64) NOT NULL,
  content_type VARCHAR(32) NOT NULL,
  title VARCHAR(160) NOT NULL,
  category VARCHAR(80) NOT NULL DEFAULT '',
  cover_key VARCHAR(160) NOT NULL DEFAULT '',
  summary TEXT NOT NULL,
  body TEXT NOT NULL,
  source_note TEXT NOT NULL,
  original_flag BOOLEAN NOT NULL DEFAULT FALSE,
  status VARCHAR(24) NOT NULL DEFAULT 'published',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS zxznh_user_artwork (
  id VARCHAR(64) PRIMARY KEY,
  tenant_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  title VARCHAR(160) NOT NULL,
  canvas_width INTEGER NOT NULL,
  canvas_height INTEGER NOT NULL,
  background_id VARCHAR(80) NOT NULL,
  layers_json TEXT NOT NULL,
  thumbnail_path VARCHAR(500) NOT NULL DEFAULT '',
  export_path VARCHAR(500) NOT NULL DEFAULT '',
  revision INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE (tenant_id, user_id, id)
);

CREATE TABLE IF NOT EXISTS zxznh_user_record (
  id VARCHAR(64) PRIMARY KEY,
  tenant_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  record_type VARCHAR(32) NOT NULL,
  target_id VARCHAR(80) NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE (tenant_id, user_id, record_type, target_id)
);

CREATE INDEX IF NOT EXISTS idx_zxznh_content_tenant_type ON zxznh_content (tenant_id, content_type, status);
CREATE INDEX IF NOT EXISTS idx_zxznh_artwork_owner ON zxznh_user_artwork (tenant_id, user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_zxznh_record_owner ON zxznh_user_record (tenant_id, user_id, record_type);

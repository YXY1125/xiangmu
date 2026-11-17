-- 仅初始化公开文化目录；不写入任何用户活动、作品、成绩或账号数据。
INSERT INTO zxznh_content
  (id, tenant_id, content_type, title, category, cover_key, summary, body, source_note, original_flag, status, created_at, updated_at)
VALUES
  ('origin', '${TENANT_ID}', 'article', '朱仙镇木版年画的源流', '年画起源', 'exhibition_classic',
   '从民间生活出发认识朱仙镇木版年画的文化脉络。',
   '朱仙镇木版年画以木版雕刻、分版套印等技艺形成鲜明风格。具体创始年代与人物存在不同资料表述，本应用不作无依据断言。',
   '国家级非物质文化遗产公开名录与权威公共文化资料；上线前逐条复核。', FALSE, 'published', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('colors', '${TENANT_ID}', 'article', '年画里的传统色彩', '传统色彩', 'thumb_traditional_colors',
   '朱砂、藤黄、青绿如何在套色中相互映衬。',
   '传统年画重视高纯度色彩的对比与节奏，具体颜料成分须以专业检测结论为准。',
   '项目文化资料组编辑记录，2026-11-13。', FALSE, 'published', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

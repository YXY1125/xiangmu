-- 仅公共花艺分类参考种子；不创建用户、密码、作品、互动或演示业务记录。
-- 生产当前由 platform/server/src/modules/floral-experience/floral.seed.ts 初始化 60/20/8/5/6/15 内容集。
INSERT INTO hytys_flower_categories (id, tenant_id, app_id, code, name, sort_order) VALUES
  ('category-main', 'hytys.xcl.huawei', 'hytys.xcl.huawei', 'main', '主花', 10),
  ('category-filler', 'hytys.xcl.huawei', 'hytys.xcl.huawei', 'filler', '配花', 20),
  ('category-bulb', 'hytys.xcl.huawei', 'hytys.xcl.huawei', 'bulb', '球根花', 30),
  ('category-line', 'hytys.xcl.huawei', 'hytys.xcl.huawei', 'line', '线条花', 40),
  ('category-foliage', 'hytys.xcl.huawei', 'hytys.xcl.huawei', 'foliage', '叶材', 50),
  ('category-special', 'hytys.xcl.huawei', 'hytys.xcl.huawei', 'special', '特殊花材', 60)
ON CONFLICT (tenant_id, app_id, code) DO UPDATE SET name=EXCLUDED.name, sort_order=EXCLUDED.sort_order;

INSERT INTO hytys_home_banners (id, tenant_id, app_id, title, description, image_key, target_type, target_id, sort_order) VALUES
  ('banner-spring', 'hytys.xcl.huawei', 'hytys.xcl.huawei', '春日第一束花', '从一枝主花开始，建立作品的焦点与呼吸感。', 'hero_home', 'theme', 'theme-spring-first', 10)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, image_key=EXCLUDED.image_key;

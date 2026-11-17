-- 仅包含可公开的咖啡基础内容示例；不创建用户、私有记录或虚假统计。
INSERT INTO coffee_public_content
  (tenant_id, content_type, category, title, summary, body, source_note, status)
VALUES
  ('kafyj.zy.huawei', 'knowledge', 'origin', '埃塞俄比亚咖啡产区入门',
   '认识主要产区常见海拔、处理方式与典型风味表达。',
   '{"regions":["耶加雪菲","西达摩"],"processes":["水洗","日晒"],"flavorNotes":["花香","柑橘","茶感"]}'::jsonb,
   '发布前由内容编辑复核来源与表述', 'draft'),
  ('kafyj.zy.huawei', 'brewing_guide', 'pour_over', 'V60 基础冲煮',
   '以稳定粉水比和分段注水建立可复现的手冲记录。',
   '{"doseGrams":15,"ratio":15,"waterMl":225,"temperatureC":92,"stages":[45,68,112]}'::jsonb,
   '参数为入门建议，需结合咖啡豆和设备调整', 'draft'),
  ('kafyj.zy.huawei', 'equipment', 'pour_over', 'V60 滤杯',
   '锥形滤杯，流速受研磨、滤纸与注水方式共同影响。',
   '{"principle":"锥形结构与螺旋肋骨形成排气和流动通道","maintenance":"使用后及时冲洗并完全晾干"}'::jsonb,
   '不包含品牌价格或未经核实的型号参数', 'draft')
ON CONFLICT (tenant_id, content_type, title) DO NOTHING;

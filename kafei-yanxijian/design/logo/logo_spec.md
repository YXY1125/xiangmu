# COFFEE LAB Logo 规范

> 适用于咖啡研习间 HarmonyOS 应用、AppGallery 和项目文档。

## 设计理念

- **App 名称**：咖啡研习间 / COFFEE LAB
- **品牌锚点**：咖啡豆与实验精神
- **核心图形**：咖啡豆嵌入烧瓶，烧瓶右侧兼作咖啡杯把手，顶部叶片表示产地生态
- **行业语义**：知识研习、冲煮实验、风味记录与长期成长

## 色彩规范

| 角色 | 色值 | 用途 |
|------|------|------|
| 主色 | `#241B17` | 烧瓶/杯轮廓 |
| 辅色 | `#B47A43` | 咖啡液与风味点缀 |
| 生态色 | `#687C68` | 叶片 |
| 背景 | `#F3EBDD` | icon_single 底色 |

## 尺寸规范

| 文件 | 尺寸 | 格式 | 说明 |
|------|------|------|------|
| icon_single.png | 1024×1024 | PNG | 单层应用图标，方角，零透明像素 |
| icon_foreground.png | 1024×1024 | PNG | 分层前景 |
| icon_background.png | 1024×1024 | PNG | 分层背景 |
| logo_export.png | 矢量导出 | PNG | 品牌 Logo |
| logo_source.png | 设计稿 | PNG | 源文件导出 |

## 使用规范

1. 完成设计后运行 `node factory/scripts/icon-validator.mjs apps/{slug}`
2. 通过后运行 `node factory/scripts/sync-app-icon.mjs apps/{slug}`
3. AppGallery 提交 `docs/store-assets/app_icon_1024.png`

## 禁止事项

- 不得替换为 scaffold 默认图标或其他 App 图标。
- 不得在小尺寸图标内加入 COFFEE LAB 文字。
- 不得改变咖啡豆、烧瓶/杯和叶片三项核心识别关系。
- 不得将本标识当作咖啡摄影或内容封面复用。

## AppGallery 合规要点

- 正方形 1:1，四角方角
- 不允许透明像素
- PNG ≤ 3MB

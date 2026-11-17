# 视觉资产流水线

- productVisualType：`content-commerce`
- stylePack：`coffee-editorial-lab`
- 生成方式：OpenAI 内置图像生成工具，2026-11-10；不是外部下载素材，也不冒充真实摄影授权
- 内容影像：8 张，均为独立生成文件与独立用途
- 首页资源引用：`hero_coffee_lab`、`banner_origin_ethiopia`、两张配方封面与器具封面
- Banner：`banner_origin_ethiopia`、`banner_brewing_lab`
- 内容封面：咖啡豆、器具、风味、拿铁配方、冷萃配方

## 清单

| key | 工程文件 | 资产归档 | 用途 |
|---|---|---|---|
| `hero_coffee_lab` | `entry/.../media/hero_coffee_lab.png` | `assets/images/content/hero_coffee_lab.png` | 首页主视觉 |
| `banner_origin_ethiopia` | `entry/.../media/banner_origin_ethiopia.png` | `assets/images/category/banner_origin_ethiopia.png` | 产地专题 |
| `banner_brewing_lab` | `entry/.../media/banner_brewing_lab.png` | `assets/images/category/banner_brewing_lab.png` | 冲煮实验室 |
| `cover_coffee_beans` | `entry/.../media/cover_coffee_beans.png` | `assets/images/cover/cover_coffee_beans.png` | 咖啡豆百科 |
| `cover_equipment_manual` | `entry/.../media/cover_equipment_manual.png` | `assets/images/cover/cover_equipment_manual.png` | 器具百科 |
| `cover_flavor_cupping` | `entry/.../media/cover_flavor_cupping.png` | `assets/images/cover/cover_flavor_cupping.png` | 风味测评 |
| `cover_recipe_latte` | `entry/.../media/cover_recipe_latte.png` | `assets/images/cover/cover_recipe_latte.png` | 奶咖配方 |
| `cover_recipe_cold_brew` | `entry/.../media/cover_recipe_cold_brew.png` | `assets/images/cover/cover_recipe_cold_brew.png` | 冷萃配方 |

每张图均要求无品牌、无文字、无水印、无商品包装；画面采用深咖啡、奶油、焦糖和植物绿的统一编辑风格。生成原图保存在 Codex 生成目录，项目交付副本已落到本 App，未从其他 `apps/{slug}` 复制。

## 当前 Gate C 边界

影像数量、独立字节、工程落盘、AppSpec 登记和页面引用已完成。真实设备截图、首页实现效果图、深色/多尺寸/对比度点击验收仍未执行，因此 Gate C 总状态仍不能写为通过。

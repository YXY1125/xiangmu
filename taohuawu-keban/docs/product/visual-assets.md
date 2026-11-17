# 视觉资产规范索引

本文件引用既有真实台账，不新增、复制或重新计数图片。AppSpec.brand.visualAssets登记91项；原始PNG位于assets/images，工程WebP副本位于app/entry/src/main/resources/base/media。原图保留，不把确定性格式转换当作新增美术。

- 首页主题：banner_taohua_print_studio、banner_qilin_color_run、banner_koi_lucky_waves、banner_printmaking_class，共4张独立插画，承担品牌、祥瑞、锦鲤和知识专题用途。
- 角色与内容：32张，包括6核心IP、生肖与瑞兽系列和节庆内容；系列存在核心角色复用，按唯一文件计数，不将系列归属相加冒充图片总数。该组不含Banner。
- 图鉴封面：8张，供分类入口使用；创作背景12张，供真实画布背景选择。
- 装饰素材：30张透明贴纸，供图层组合；空状态5张，区分草稿、搜索、收藏等场景。

唯一文件总数为4 Banner + 32角色/节庆内容 + 8图鉴封面 + 12背景 + 30贴纸 + 5空状态 = 91。分组机械检查以engineering-images.json为准，其中cover目录含4 Banner与8图鉴封面共12张，content目录32张。

逐图文件名、所属模块、用途、来源、授权状态、版权说明、分辨率、格式和原图SHA256的权威表为 docs/ImageManifest.md。WebP目标文件、尺寸、Alpha和质量检查记录为 docs/validation/engineering-images.json；图片完整性检查为 docs/validation/image-integrity.json（若需重验，执行现有audit_images.py）。

工程引用经MediaCatalog静态$r映射后由真实API资源键选择；画布使用背景和透明图层，正文角色使用contain、主题场景使用cover。文件可解码及静态引用不证明每个屏幕无拉伸或裁切问题，后者须设备验收。

权利状态：productionReleaseApproved仍false。用户表示已有权利审核结论，但截至本次记录尚未给出可核对的位置；不得把此索引当作版权批准。完整版权边界与来源记录见 image-copyright-record.md。

缺口：已确认首页效果图、全部页面/深色/屏幕适配截图与完整Gate C验收未完成。不存在用纯色图、重复图片或系统诊断截图补足验收的处理。

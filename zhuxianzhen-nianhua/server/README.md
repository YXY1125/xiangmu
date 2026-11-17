# 专属服务说明

本目录给出朱仙镇年画专属 API 契约与隐私接口，不包含密钥。生产目标为 saas26；App 专属 NestJS 模块、管理端入口、租户清单与 runtime 已部署，目标管理员在现有账号表中创建。公开内容通过 App 专属管理 API 写入现有文档存储；数据库结构迁移未执行。

生产 App 使用 `https://saas26.qianqi.online/api/v1`，所有请求带 `X-Tenant-Id: zxznh.xcl.huawei`。2026-11-13 公网验证健康、12 角色、7 文章、6 专题、20 模板、5 游戏配置及五类用户记录空态通过；Admin 内容更新后 App API 同步可见并已恢复。

最近定点模块回退目录：`/www/wwwroot/saas26.qianqi.online/.backup-zxznh-module-2026-11-13T05-10-53-492Z/zhuxianzhen-art`。后续部署仅允许目标模块和公开栏目增量，不能再次覆盖已有用户 runtime。

2026-11-13 再次复核：现有租户可用，无需重复注册。后台登录 /login、专属菜单 /zxznh-art 与线上异步页面模块正常；管理员仅能看到本应用租户，七类公开目录与 App API 同源。访问说明见 docs/saas26-admin-access.md，脱敏在线报告见 docs/validation/saas26-integration.json；本次没有执行部署或覆盖内容。

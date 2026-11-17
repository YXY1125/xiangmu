# 业务接口与 SaaS26 集成

权威契约：AppSpec v1.3（CR003 已获用户确认，Gate A 复验通过）。实际实现：server/src/http.mjs、service.mjs；生产入口源文件：server/src/main.ts；账号注销委托：server/src/modules/privacy/privacy.controller.ts。tools/build_server.mjs编译上述真实入口，production.mjs仅作宿主兼容导出；生产宿主：platform/server/src/modules/thwkb/thwkb.module.ts。

## 身份和响应

客户端基址为 https://saas26.qianqi.online/api/v1。所有应用请求带 X-Tenant-Id: thwkb.zh.huawei；私有请求带当前认证返回的 Bearer 会话。登录、注册、会话撤销复用 SaaS26 AuthService，不自建账号表。业务代码仅信任 resolveAppSession 的 id/tenantId，不信任 body.userId。

统一响应包含 code、message、data；0 表示服务端确认成功。40001 参数错误、40101 会话无效、40301 无权限、40401 记录不存在、40901 修订或状态冲突、42201 业务校验失败、50001 服务错误。当前客户端支持 HTTP 401 及业务 40101，同时清除内存与持久化会话。服务器不在错误响应或日志中回传 SQL、请求体或连接信息。

## 公开读取

home 编排已发布主题、有效分类、角色、作品、排行、知识；已认证用户另含自己的最近浏览。characters 支持 category/q；knowledge 支持 q；materials 仅返回 published 且具备 in_app_composition 授权的素材。templates 返回真实图层文档。plaza 支持 q/order/cursor；每页20条，nextCursor 为空表示结束，liked=mine 时必须认证。authors/:id 仅返回昵称、授权头像、简介与公开作品；不返回账号、电话或私有记录。

角色详情关联作品按实际素材引用计算，史实文章仅返回 factCheckStatus=verified 的内容与 sourceRecords。现代角色明确标注原创设定。

## 创作、版本与发布

POST creations 新建时 revision 必须为0、templateId必须指向本应用已发布模板；PUT creations/:id 必须带服务器上次返回的 revision，不能替换既有创作的原始模板来源。冲突返回40901，不覆盖其他编辑。文档 schemaVersion=1、800×1000、最多60层，素材 id 与 imageKey 必须匹配当前应用的授权资源；坐标、缩放、旋转、文字颜色和长度均校验。DELETE creations/:id 只归档，保留业务记录。真实PostgreSQL测试发现并修复了原实现templateId为空的问题，未放宽冻结契约或初始迁移约束。

POST creations/:id/artwork 从本人 completed 创作生成不可变版本。同一创作修订号重复请求返回同一作品。版本包含画布快照、素材引用、修订号、版权声明；后续编辑原创作不改变该版本。

POST artworks/:id/publications 必须主动确认 rightsConfirmed；submitted/rejected/offline 不能公开。只有受信管理员确认版权并 approved 后可进入广场；下架即不可公开读取。收藏、点赞、历史按本人身份幂等维护；举报只针对当前公开作品。

## 反馈和通知

feedback 的提交及列表仅当前用户可访问。submitted→reviewing→replied→closed，允许直接回复已提交反馈。回复写入本人通知。notifications/:id/read 必须属于本人；不存在和他人记录均返回40401。

## 管理边界

admin/:kind、作品审核、举报复核、反馈回复、内容状态操作使用平台 AdminAuthService 的受信会话。仅 thwkb.zh.huawei 活动租户；tenant_operator 只读，tenant_admin/platform_super 允许写入。请求体中的 role/tenantId 不授予权限。管理资源有白名单，不提供通用任意表访问。

## 运行状态与开发方式

生产运行必须配置THWKB_APP_ROOT及THWKB_DATABASE_CONFIG_FILE（root专属配置文件路径），或安全环境中的THWKB_DATABASE_URL。业务进程不在PM2参数/日志中携带口令；配置错误仅返回脱敏诊断，远程URL要求验证TLS。缺少时本应用不可用且不回退文件，不影响其他租户。2026-11-11已完成生产数据库和API宿主精确增量部署，真实HTTPS25项验证认证/A-B隔离/反馈/退出/注销；正式内容未导入，完整创作审核与管理员UI仍未验收，不等于Gate B通过。

本地显式执行 node server/dev.mjs --development-file-store，绑定127.0.0.1，复用当前平台认证源码和隔离的数据目录。客户端只有 DEBUG=true 且启动参数 thwkbLocalApi=true 时允许固定127.0.0.1:43126，页面显示“本地联调·文件存储·非生产服务”；发布包不启用 HTTP。此模式不替代 PostgreSQL 和生产 Gate B。

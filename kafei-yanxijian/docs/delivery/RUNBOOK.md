# 本地运行与验证

## HarmonyOS 客户端

使用 DevEco Studio 打开 `apps/kafyj.zy.huawei/app/`。工程要求 SDK `5.0.0(12)` 与 JBR。命令行构建使用 DevEco 自带 Node 和 hvigor wrapper：debug 或 release `assembleHap`。当前没有签名配置，输出为 `entry-default-unsigned.hap`。

客户端默认连接 `https://saas26.qianqi.online/api/v1`，请求头 `X-Tenant-Id: kafyj.zy.huawei`。目标租户和咖啡业务模块已于 2026-11-11 定向部署；联网失败时仍显示真实错误，不会回退到模拟 Token 或假数据。

## 本地服务端

在 `server/` 设置至少 24 字符的 `SESSION_SECRET`，执行 `npm start`。默认监听 `127.0.0.1:3108`。仅为本地联调时可把客户端 API 地址改为 HTTPS 反向代理地址；客户端拒绝明文 HTTP。

执行 `npm test` 运行隔离、记录保护和账号注销测试。`server/data/runtime.json` 是运行期本地文件并被 `.gitignore` 排除；不要放入真实用户数据。

## 数据库

`db/migrations/001_init.sql` 与 `db/seeds/001_seed.sql` 不会自动执行。生产应用前必须由数据库负责人审核并通过 V5.0 迁移流程，禁止直接修改共享 Schema。

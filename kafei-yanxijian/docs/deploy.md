# 部署说明

## 服务端

### saas26 生产集成

生产环境已使用 `platform/server/src/modules/coffee-culture/` 集成模块，复用平台认证与租户注册表，不运行独立 `runtime/server.mjs`。执行 `node apps/kafyj.zy.huawei/server/scripts/deploy-saas26-targeted.mjs --audit` 可做只读审计；显式 `--deploy` 仅用于本租户定向修复，并会先备份生产入口。禁止用全站部署脚本覆盖其他租户或用 allowlist 清理共享环境。

生产私有数据当前写入 saas26 本租户独立运行目录，使用原子文件替换并由平台会话强制 userId 隔离。正式数据库迁移仍须另行评审；不得为完成清单直接修改共享 Schema。

### 本地独立联调

1. 使用 Node.js 20+，在 `server/` 按 `.env.example` 注入 `PORT` 与至少 24 字符的 `SESSION_SECRET`；真实密钥不得写入仓库或命令行日志。
2. 先执行 `npm test`；通过后使用 `npm start` 启动无第三方依赖的 `runtime/server.mjs`。
3. 运行时默认仅监听 `127.0.0.1:3108`，只用于本地契约测试；保留 `/api/v1` 路径及 `X-Tenant-Id: kafyj.zy.huawei`。
4. `server/data/runtime.json` 只用于独立联调。正式数据库迁移前须审核 `db/migrations/001_init.sql`，不得直接改共享 Schema 或覆盖已有数据。
5. 部署后逐项验证注册、登录、401、学习/收藏/打卡幂等、制作/配方/测评写入、成长统计刷新、双账号隔离和账号注销。

## HarmonyOS 客户端

1. DevEco Studio 打开 `apps/kafyj.zy.huawei/app/`，SDK 使用 `5.0.0(12)`。
2. 默认服务地址为 `https://saas26.qianqi.online/api/v1`；客户端拒绝明文 HTTP，且网络失败不会生成离线 Token 或模拟业务数据。
3. 发布前配置目标华为开发者账号的签名 Profile/证书，分别执行 Debug 与 Release `assembleHap`，再解包核对 Bundle、版本、权限与图标。
4. 不在仓库、报告或聊天中提交证书、口令、Token 或审核账号密码。

## 上架验收

1. 核对已确认的华为开发者账号名称“黑龙江省云富信息科技有限公司”与法律文件运营者字段一致。
2. Gate C、合法摄影、真实截图、公开隐私 URL、审核账号与 saas26 公网接口全部通过。
3. 在真机完成浅/深色、多尺寸、无障碍、弱网、IPv6、权限、性能和完整业务闭环回归。
4. 提交前重新执行 `CHECKLIST.md`、Gate A、Gate B、Logo_Check 和发布包核验。

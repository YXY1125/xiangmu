# 数据模型与隔离

公共域包括 CoffeeOrigin、CoffeeBean、CoffeeKnowledge、BrewingGuide、CoffeeEquipment 和官方 CoffeeRecipe。用户私有域包括 UserProfile、UserRecipe、BrewingRecord、FlavorEvaluation、Favorite、LearningRecord、DailyCheckIn 与成长/成就聚合。

每条私有记录必须包含 `tenantId`、`userId`、状态、版本与审计时间。服务端从签名会话派生 tenantId/userId，查询条件必须同时使用二者。编辑配方或制作记录创建新版本并保留 `parentVersionId`；移除展示使用 `archived`，不执行 DELETE。

账号注销将账号标记为 closed，清空姓名与电话、替换登录标识和密码哈希、归档用户业务记录，并使已有 Token 因账号状态检查立即失效。公共内容不混入用户私有统计。

项目级迁移位于 `db/migrations/001_init.sql`，仅为审批草案；尚未修改共享或生产数据库。公共初始内容位于 `server/data/public-content.json`，不含虚假用户记录。

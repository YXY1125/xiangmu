# 数据模型与迁移说明

AppSpec v1.3 声明16个业务实体。server/contracts/entities.json 为契约副本，不修改公共 Schema；平台账号仍由 SaaS26 维护。

公开内容：Category、Character、Topic、KnowledgeArticle、Material、Template。记录具有 tenantId/appId、内容状态、时间及来源/权利信息。Artwork 区分 official/user_original；用户版本关联 Creation，公开展示另由 Publication 审核决定。

私人记录：UserProfile、Creation、Publication、Favorite、Like、BrowseHistory、Report、Notification、Feedback；所属用户一律来自可信会话。Artwork 的 ownerUserId 同样来自服务端。公开作者只提供显式白名单字段。

001_init.sql 创建原始15表及复合主键、外键、查询索引和唯一关系；002_feedback.sql 为 CR003 追加表。原文件001_initial.sql在任何数据库执行前仅重命名为工厂约定路径，SQL内容不变。复合外键包含 tenantId/appId，延迟约束允许注销事务有序清理关联。收藏、点赞、历史和资料均有业务唯一索引。多态收藏/历史的目标由业务层校验。

PostgresRepository使用参数化语句、固定契约白名单、应用范围WHERE条件、事务及advisory lock。读使用一致快照，写比较版本后提交；本机真实PostgreSQL8项已验证保存恢复、并发和隔离。用户后续授权的独立生产PostgreSQL17.11亦已完成001/002迁移、16业务表、受限角色及数据库权限/约束/备份恢复验证，生产业务记录均0。生产API可信认证上下文下的A/B与全业务仍待联调，不能将数据库检查直接当作Gate B。

database.mjs是原环境URL开发运维入口；生产开通/迁移使用授权的remote_provision_postgres.mjs，通过专用本机peer管理员角色执行，运行期业务角色不具备DDL。API可通过THWKB_DATABASE_CONFIG_FILE读取远端root专属0600配置，或安全URL；从不把口令写入命令参数/报告。seed-approved要求根发布批准、已发布素材/作品权利批准及知识核验，不覆盖既有记录。001_seed.sql实际含160条导入语句，但当前在事务首部阻断发布批准待完成，生产没有导入；不是空SQL。

当前种子：14分类、24角色、4主题、12篇带可靠来源的文化文章、74个可组合素材、12模板、20份官方内容（12组合版与8节庆插画）。素材背景包括12专用背景和8可复用节庆场景，不是新增图片凑数；91张原图仍唯一登记。八个图鉴入口按实际角色或作品类型查询，生肖12、瑞兽8、核心IP6、节庆8、四季主题4，均有真实服务数据。所有用户私人实体为空，没有种子用户作品、点赞、收藏、历史、消息或反馈。种子明确标记 development-content-review / productionReleaseApproved=false，正式发布须先归档权利并审查内容。

创作 DELETE 仅归档；退出仅清会话，不删除业务记录。注销需真实认证且空请求体，先清理当前用户业务及指向其作品的依赖关系，再撤销平台账号和会话。数据库不可用时拒绝注销，不伪报成功。跨平台认证文件与 PostgreSQL 不是分布式原子事务，故仍需真实故障重试和恢复验收。

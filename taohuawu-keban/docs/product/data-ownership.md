# 数据模型与归属

## 公共内容

Category、Character、Topic、KnowledgeArticle、Material、Template 由管理端维护，只有 `published` 且通过来源/版权检查的记录可被游客读取。公共记录仍包含 `tenantId` 与 `appId`，不得跨租户混用。

## 私有数据

UserProfile、Creation、用户 Artwork、Favorite、Like、BrowseHistory、Publication、Report、Notification、Feedback 均以服务端认证上下文取得 `userId`。客户端请求体中的同名字段即使存在也不得作为授权依据。

## 生命周期

- 创作：`draft ↔ completed → archived`，DELETE 接口仅归档，不物理删除；退出登录不删除。
- 发布：提交后 `submitted → approved | rejected`；`approved → offline`，拒绝或下架后重新提交形成新审核记录。Artwork 为不可变快照。
- 举报：`submitted → reviewing → resolved | dismissed`。
- 公共素材内容状态：`draft / published / offline`；授权依据独立保存在 licenseRecord，缺少组合授权不得发布或用于画布。
- 反馈：`submitted → reviewing → replied → closed`，允许直接从 submitted 回复；仅本人和受信管理员可读。
- 知识文章：来源待核验时不得发布；核验拒绝不进入前台。

## 唯一关系

收藏键为 `(tenantId, appId, userId, targetType, targetId)`；点赞键为 `(tenantId, appId, userId, artworkId)`；浏览历史对同一目标更新次数和最近访问时间，不重复插入无限记录。

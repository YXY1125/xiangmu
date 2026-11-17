# 数据结构与隔离

## 内容数据

文化文章、原创角色、专题、模板和游戏配置由 saas26 的 App 专属运行目录提供；网络不可用时使用同版本的应用内结构化内容缓存。所有生成角色和展览图明确标记为现代原创视觉，不作为历史文物证据。

## 用户数据

`LocalDataStore` 以 `userId` 或本机 guest namespace 分区保存收藏、作品完整图层配置、游戏记录、学习记录和浏览记录。登录、退出或换号会切换 namespace，禁止读取上一身份的数据。作品图片存储到应用文件目录，Preferences 只保存结构化索引，不写入大图二进制。

主要实体：`UserProfile`、`NewYearPicture`、`CulturalArticle`、`Character`、`CharacterAsset`、`Exhibition`、`ExhibitionItem`、`CreativeTemplate`、`CreativeAsset`、`UserArtwork`、`ArtworkLayer`、`Favorite`、`GameConfig`、`GameRecord`、`Achievement`、`UserAchievement`、`LearningRecord`、`BrowsingRecord`。

## 版本和异常

本地存储带版本键；读取失败返回空集合并保留原持久数据。当前账号的写入存入独立 syncOutbox，成功后只确认相同版本；离线失败、重启和并发修改不会静默清除重试项。登录/前台/主动同步拉取收藏、作品、游戏、学习与浏览进度。游客不自动合并，旧本地独有记录加入队列，另一设备的图片路径不当成本机有效文件。

请求发出时锁定 token/owner；换号后的迟到数据不进入新账号，迟到401也不注销新会话。图片实际保存在 filesDir/artworks/{encodedOwner}/，Preferences 仅保存结构化索引。创作模型另存 clientCreatedAt/clientUpdatedAt，避免服务端审计时间覆盖编辑时间。

`db/migrations` 与 `db/seeds` 仅为数据库设计交付件，本次未获数据库 Schema 执行授权，因此没有运行。

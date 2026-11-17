# 桃花坞刻版项目总览

目标：让传统年画变成可爱的动漫世界，以现代原创角色、可恢复的本地素材组合工坊、可靠文化知识与审核后作品展示构成业务闭环。不是传统原画复制或AI绘图产品。

事实来源：AppSpec v1.3；五Tab为首页、图鉴、工坊、广场、我的。需求见product/positioning.md、feature-list.md；场景见user-personas.md；页面见information-architecture.md；闭环见core-flows.md；归属见data-ownership.md。原始15实体已按用户批准CR003扩展Feedback，共16实体。

视觉：design/ui-design-spec.md；Logo见design/logo/logo_spec.md（应用根design/）；角色见product/ip-character-bible.md与design/content-labels.json；91张原图、来源、权利及工程副本见ImageManifest和image-copyright-record。生成式图像仅用于开发期资产制作，不向App用户提供AI功能。

实现：原生ArkUI/ArkTS，复用Core Kernel通用组件；SaaS26统一认证；本应用独立业务服务、PostgreSQL适配和迁移；私有数据可信身份隔离；本地副本只作恢复，不冒充服务端保存。API与数据说明见api-contract.md、data-model.md。

阶段：S0审查、Gate A、Logo/S3.5已形成真实文件和检查；当前S4/S5实现与局部测试。S6生产联调及Gate B/C、正式测试/打包/发布未完成。每次增量见stages/；真实检查见validation/。既有未提交成果保留；共享平台修改限于用户批准的本应用集成，不升级依赖或修改公共Schema。

当前外部输入：PostgreSQL安全配置；后续独占设备；公开隐私联系方式与运营安排；正式素材权利及签名材料。缺失时暂停对应步骤，不伪造结果，不越过门禁。当前清单、测试、性能、隐私和发布进度分别见CHECKLIST.md及对应报告。

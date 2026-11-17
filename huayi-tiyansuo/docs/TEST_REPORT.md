# 测试记录

执行日期：2026-11-13

## 已实际执行

- Gate A：CR004 写入已核验运营者后，`node runtimes/validate-gate-a.mjs apps/hytys.xcl.huawei` → PASS；AppSpec 与 GenerationRequest 两份 Schema 均通过，冻结版本 1.6。
- Gate B 结构校验：`node runtimes/validate-delivery.mjs apps/hytys.xcl.huawei` → PASS（仅结构范围；人工发布项不在此结论内）。
- 敏感信息扫描：最终重签后先识别出 DevEco 写入的 2 个内联凭据字段；固化验签产物并清除源码凭据后重跑严格扫描 → PASS，扫描 126 个文件，0 项发现、0 项扫描错误。
- Logo：`icon-validator.mjs`、`logo-brand-check.mjs` → PASS。
- 服务端：`npm run build` → PASS。
- 花艺业务自动化：`npm run test:floral` → 1/1 PASS；覆盖 60 花材、20 课程、8 主题、5 挑战、6 活动、15 成就、用户隔离、草稿/发布、挑战条件、点赞收藏幂等、课程收藏、学习进度、活动参加提交、运行时内容配置、持久化、个人聚合及账号数据清理。
- 管理端：`npm run build` → PASS；存在两项共享菜单的历史重复 key 警告（`hcArticles`/`hcSupplies`），非本 App 引入。
- HarmonyOS HAP：设备回归后的最终正式签名 HAP 51,497,311 bytes，SHA-256 `287db73f2bda9545d685c60d7a1943687f061ba290d4102915c836d430b7b1d6`，`verify-release.mjs` 与 `hap-sign-tool verify-app/verify-profile` → PASS；覆盖安装到 API 24 模拟器并启动成功，工坊操作按钮完整可见。
- HarmonyOS APP：设备回归后的最终 AppGallery APP 48,729,746 bytes，SHA-256 `b03ab1436872ca459b89909aff45737ae722be8ad3907f4475e336aa72ac0784`，直接包验签与内嵌 Profile 验证 → PASS。
- HarmonyOS 构建：最终源码 Hvigor `assembleHap --no-daemon` 与 `assembleApp --no-daemon` 均为 BUILD SUCCESSFUL；签名产物已固化到 `artifacts/`，DevEco 写入的内联签名配置随后从源码清除。
- Release Profile：`hap-sign-tool verify-profile` → PASS；类型 `release`，Profile 内 Bundle Name 为 `hytys.xcl.huawei`，与目标工程一致。公共证书及共享密钥库文件存在；密钥库非空口令，未从其他应用复制或输出别名、口令及私钥。
- 设备：`hdc list targets` → `127.0.0.1:5555`，HarmonyOS API 24 模拟器。真实安装、启动、点击、滑动、进程停止/重启和截图均已执行，证据位于 `docs/validation/device/`。
- 设备主流程：完成首页→玫瑰详情→用它创作→保存；课堂五步学习至 100%→工坊→发布；自由创作→草稿→强停重启恢复→发布；花园点赞/收藏→重新加载保持→作者主页；圣诞活动参加→推荐素材进入工坊→发布→提交；活动提交后“节日花艺师”“主题挑战者”等真实成就解锁。
- 设备专项：验证注册协议默认未勾选、注册登录、单指拖拽、添加/删除素材、撤销/重做、图层上移、花材收藏、课程收藏持久化、个人中心 4 件作品/1 草稿/8·15 成就统计刷新，以及注销二次确认和账号数据清理。一次性 QA 账号已在测试结束后注销。
- 未自动化项：模拟器 UI 注入工具只支持单指，未把双指缩放/旋转伪报为通过；深浅色、不同尺寸/安全区域和物理真机仍待补测。
- saas26 增量部署：花艺服务与租户已部署。为保持真实日期下存在首发可参加活动，将圣诞活动开放期配置为 2026-11-01 至 2026-12-26；应用级 seed-only 增量部署及运行目录公共 catalog 同步成功，公网确认状态 `active`，回退备份为 `backups/hytys-20261113072851`。公网计数仍为 `materials=60`、`tutorials=20`、`themes=8`、`challenges=5`、`events=6`。
- 公开法律页：`deploy-privacy-html-saas26.mjs hytys.xcl.huawei` 定向部署成功；隐私政策、用户协议、未成年人说明逐页公网 GET 均为 HTTP 200 且标题匹配。
- 认证 API 冒烟：`node tools/api-auth-smoke.mjs` → achievements 15、works、dashboard 全部 PASS；进程内随机测试账号在 finally 中自动注销，未记录账号或密码。
- 发布预检：最终重签已消除签名阻塞；Gate A、结构 Gate B、敏感信息和当前候选包验签通过。其余仍为仓库全局大量缺失跟踪文件、目标 App 未纳入版本跟踪及人工发布项。未执行恢复、暂存或覆盖其他工作区改动。

## 自动化覆盖的业务闭环

数据层和 API 24 模拟器 UI 层均已验证保存草稿→发布→公开列表、作品互动、课程进度与收藏、活动参加→本人公开作品提交、行为触发成就、进程重启恢复、用户注销清理。物理真机、双指手势、深浅色和多尺寸仍未完成，不将模拟器结果表述为真机通过。

## 2026-11-13 画布与统计同步专项修复

- 复现确认：旧实现点击花材后仅更新“已添加”文字，布局树没有生成画布素材节点；画布对象手势还会被外层纵向滚动和图片原生拖拽抢占。
- 修复：画布改用不可变对象更新和显式渲染版本，图片禁用原生拖拽，素材使用优先手势；操作按钮改成两行等宽布局，移除“下移/上移”，第二行仅保留完整显示的背景与容器按钮。
- 设备验证：玫瑰、郁金香均真实显示；单指拖动后郁金香可见边界由 `[413,796][553,851]` 变为 `[590,644][730,699]`；背景、花篮和撤销按钮实际生效。
- “我的”修复：增加标签页刷新版本与登录会话监听；进入“我的”时强制拉取作品、成就和 dashboard 聚合数据，退出登录时清空旧用户状态。
- 数据验证：新账号初始统计为 0；保存草稿后自动显示作品 1、草稿 1、成就 1/15；收藏玫瑰后花材收藏变为 1、成就变为 2/15。一次性账号及数据随后通过账号清理 API 删除。
- 最新修复版签名 HAP：51,497,311 bytes，SHA-256 `287db73f2bda9545d685c60d7a1943687f061ba290d4102915c836d430b7b1d6`。已覆盖安装至 API 24 模拟器，布局树确认存在“撤销、重做、删除、清空、奶油背景、换花篮”，不存在“下移、上移”；截图为 `docs/validation/device/workshop-buttons-final.jpeg`。

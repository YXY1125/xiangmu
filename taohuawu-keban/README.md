# 桃花坞刻版

HarmonyOS原生素材组合创作、原创角色图鉴与年画文化学习应用。开发主体与独立核实的华为开发者账号名称均为黑龙江省众富信息科技有限公司，两项身份含义不混同。包名thwkb.zh.huawei，SDK目标5.0.0(12)，默认不提供生成式AI功能。

工程根app/；管理后台复用platform/admin，说明见admin/README.md。AppSpec v1.3为冻结事实来源。上架Logo索引：[store/logo/preview-1024.png](store/logo/preview-1024.png)，权威方角图为design/logo/icon_single.png；DevEco分层图标再处理要求见app/README.md。

验证命令：node tools/test.mjs；node tools/test_postgres.mjs（仅本应用便携本地PostgreSQL环境）；node tools/check_admin.mjs（独立Vue入口，不覆盖共享dist）；powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1。命令以仓库根执行时需加apps/thwkb.zh.huawei/前缀。

tools/sync_legal.mjs将本应用四份store法律候选正文同步到客户端；仍为开发草案，不代表隐私审查通过。tools/record_checkpoint.mjs与tools/release_preflight.mjs只聚合真实证据，任何缺口保持阻塞，不自动晋升Gate或执行生产操作。

当前不是可上架成品。真实测试与剩余条件见CHECKLIST.md、docs/test-report.md、docs/release-readiness.md及docs/validation/CHECKPOINT.json。不要从其他App复制签名材料，不上传当前含无关改动的整份平台dist，不提交.runtime、密码或连接字符串。

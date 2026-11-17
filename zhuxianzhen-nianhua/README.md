# 朱仙镇年画

面向 HarmonyOS 的原生传统文化数字创意应用。工程包含五导航内容体验、12 个原创角色、文化专题、分层创作编辑器、五种小游戏、用户本地数据隔离、saas26 内容接口和管理端入口。

- App 工程：`app/`
- 原创内容素材：`assets/images/content/`
- AppGallery 图标：`store/logo/preview-1024.png`
- 分层桌面图标：`app/AppScope/resources/base/media/`
- 产品文档：`docs/`
- 数据库设计稿：`db/`（未执行迁移）
- App 专属接口契约：`server/`

## 构建

使用 DevEco Studio 5.0.5.315+ 与 SDK `5.0.0(12)`：

```powershell
& '<DevEco Studio 安装目录>\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p module=entry@default -p buildMode=debug --no-daemon
```

本地已验证签名 Release APP/HAP 构建、API 24 模拟器安装启动、五导航，以及作品保存后的重启恢复。构建产物、签名材料、口令、内部账号与部署验证记录不纳入公开仓库。

saas26 租户标识为 `zxznh.xcl.huawei`。运行时凭据通过安全环境配置，不写入源码或公开文档。

签名构建使用 `scripts/build-signed.mjs`，从本机受保护配置读取已有密钥库配置；临时注入后在 `finally` 中恢复工程文件。

当前素材包含原创内容位图与 SVG 纹样；素材清单和视觉方向见 `docs/ImageManifest.md` 与 `docs/product/`。项目不包含历史作品图库。

业务自动测试、小游戏结算与记录保存已在本地验证。真机、最低版本、双账号/双设备与 AppGallery 提交流程仍需在对应发布环境中复核。

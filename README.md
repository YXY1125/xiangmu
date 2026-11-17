# HarmonyOS 项目合集

本仓库收录四款 HarmonyOS 应用的公开源码。每款应用均保留独立工程、服务端源码、资源和公开文档；构建缓存、运行数据、签名材料、内部账号及部署验证记录未纳入仓库。

## 应用目录

- [`zhuxianzhen-nianhua/`](zhuxianzhen-nianhua/) — 朱仙镇年画
- [`taohuawu-keban/`](taohuawu-keban/) — 桃花坞刻版
- [`huayi-tiyansuo/`](huayi-tiyansuo/) — 花艺体验所
- [`kafei-yanxijian/`](kafei-yanxijian/) — 咖啡研习间

## 开发环境

- DevEco Studio 5.0.5.315 或更高版本
- HarmonyOS SDK `5.0.0(12)`
- Node.js 20 或更高版本（服务端及辅助脚本）

进入目标应用目录后，使用 DevEco Studio 打开其中的 `app/` 目录。公开版 `build-profile.json5` 不包含签名配置；如需发布签名包，请在本机安全环境中单独配置证书和密钥库。

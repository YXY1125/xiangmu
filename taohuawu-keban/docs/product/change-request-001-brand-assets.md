# CR001 — 品牌 Logo 与首批视觉资产登记

日期：2026-11-10

## 原因

Gate A 通过后按 V5.0 进入 S2 Logo 与 S3.5 图片阶段，需要把已实际落盘的 Logo 路径、生成器类型和首批 4 张 Banner、6 个核心 IP 文件登记到 `AppSpec.brand`。`APPSPEC_FREEZE.md` 将 `brand.logo / brand.visualAssets` 路径登记列为无需 Change Request 的允许修改，但当前 `validate-gate-a.mjs` 只比较整文件 hash，因此仍要求记录后才能恢复门禁通过。

## 变更范围

- 完善 `brand.logo`：`glyphStrategy`、概念、生成器、渲染脚本和资产路径。
- `brand.visualAssets` 从空数组登记为 10 个真实文件及用途。
- 不修改 `identity`、`positioning`、`modules.pages`、`coreFlows`、`entities`、`apis`、`access`、`permissions`、AI 开关或商店功能声明。

## 影响分析

- DB / Server / API：无数据契约变化。
- HarmonyOS Model / Service / 页面：仅新增可引用媒体资源，不改变业务路由。
- 权限 / 隐私：无新增权限或采集项。
- Gate：需更新冻结 checksum，并重跑两份 Schema、Gate A 回归、Logo 检查和后续 Gate C。

## 校验事实

变更后的真实 Gate A 首次返回 block，唯一阻塞为冻结 checksum 不一致；两份 Schema 均为 pass。旧 checksum `25510434da6487201c2a553c887a61c9fd752823e313c106357a9de38a5c55d0` 保留在冻结历史字段，新 checksum 见更新后的 `APPSPEC_FREEZE.json`。

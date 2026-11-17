# 项目架构

## 客户端

HarmonyOS ArkTS / ArkUI 单 HAP 工程，SDK `5.0.0(12)`。`pages/` 按业务建立独立页面，`services/` 负责 HTTPS、会话、咖啡 API 与计算，`models/` 提供显式类型，`components/design-system/` 提供统一主题和状态组件。默认 API 为 `https://saas26.qianqi.online/api/v1`。

`CoffeeApi` 是私有业务写入的统一入口；成功写入后由 `CoffeeSync` 更新 `AppStorage.coffeeDataRevision`。依赖数据的页面使用 `@StorageLink + @Watch` 重新拉取服务端，并用单调请求序号丢弃过期响应，避免快速写入、换号或筛选时旧数据覆盖新数据。

## 服务端

`server/runtime/` 是用于本地契约测试的 Node.js 20+ 独立实现。saas26 生产使用 `platform/server/src/modules/coffee-culture/` NestJS 模块并复用平台 `AuthService`；私有请求的 tenantId 与 userId 来自平台签名会话。业务记录采用新增版本、归档或匿名化，不物理删除。学习、收藏和每日打卡具有业务幂等键；成长和测评聚合每次从当前用户持久化记录计算，不接受客户端传入统计值。

## 数据

`server/data/public-content.json` 是可维护的公共内容初始集，并已部署到 saas26 的本租户独立运行目录。生产私有数据当前同样在该目录使用原子文件替换持久化，所有读写按租户、应用和平台用户身份过滤；未修改共享核心 Schema。`db/migrations/001_init.sql` 仍是待评审迁移草案，尚未应用到共享数据库。

## 安全边界

客户端不保存密钥，不生成离线 Token；注册协议默认不勾选；401 清理会话；账号注销匿名化身份并归档业务记录。媒体接口仅接受 JPEG/PNG、限制 5MB，并按租户/用户目录隔离。

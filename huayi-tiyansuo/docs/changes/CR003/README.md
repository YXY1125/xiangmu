# CR003 — API 契约与真实实现统一

原因：P6/S7 实现采用应用级 `/floral/*` 控制器以支持 saas26 精确增量部署，早期 AppSpec 仍登记 `/biz/hytys.xcl.huawei/*` 设计路径。

变更：仅更新 AppSpec API 路径、HTTP 方法与摘要，使其与已编译、自动化测试并部署的 FloralController 完全一致；身份、页面、实体、权限、AI=false、Bundle Name 和产品定位不变。

验证：更新冻结校验和后重新执行 Gate A；客户端、服务端测试和公网公共内容 smoke 已通过。

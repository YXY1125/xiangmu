# CR001 — S3.5 视觉资产清单补充

- 基线：Gate A 冻结的 AppSpec `3569ba682cbc52f7dbdaab3011ce87637594842f1f84b431d577b59f3c654455`
- 原因：Gate A 后按 V5.0 S3.5 完成正式影像生产，需要把已生成文件登记到 `brand.visualAssets`。
- 影响：只新增本 App 的资源元数据，不改变身份、行业包、访问模式、实体、API、AI 状态或权限。
- 回退：恢复本目录保存的基线 AppSpec，移除本 App `brand.visualAssets` 新增项；不涉及共享 Schema 或其他租户。
- 资产来源：内置 imagegen；原始输出副本保存在 `assets/downloads/source/`，正式资源保存在 `assets/images/` 与工程 `media/`。
- Logo 事实校正：Logo 是本 App 独立设计的 SVG 几何标志，由 `store/logo/render_logo.py` 确定性渲染，并非 imagegen 输出；将 `brand.logo.generator` 校正为 `custom-vector-render` 并登记渲染脚本。该校正不改变 Logo 图形和业务范围。

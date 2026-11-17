# 朱仙镇年画 Logo 资产

- `symbol.svg`：品牌 Symbol 矢量源
- `logo-horizontal.svg`：横版锁定稿
- `foreground.png` / `background.png`：HarmonyOS 分层图标源
- `preview-1024.png`：AppGallery 首选预览
- `agc-216.png`：216px 预览
- `render_logo.py`：确定性栅格化脚本

运行 `python render_logo.py` 后，再执行仓库 Logo 同步与校验命令。发布前以 `design/logo/icon_single.png`、工程 media 和 AppGallery 上传图哈希一致为准。

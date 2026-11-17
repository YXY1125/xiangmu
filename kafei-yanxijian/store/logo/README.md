# 精品品牌 Logo — kafyj.zy.huawei

| 文件 | 说明 |
|------|------|
| `concept.md` | 关键词、对比策略、自检 |
| `symbol.svg` | 纯 Symbol 矢量源 |
| `logo-horizontal.svg` | Symbol + Wordmark 横版 |
| `foreground.png` / `background.png` / `preview-1024.png` / `agc-216.png` | 位图分层 |

工厂命令：

```bash
python3 tools/harmonyos-app-logo/scripts/premium_logo.py --app-spec apps/kafyj.zy.huawei/AppSpec.json
node runtimes/ensure-app-logo.mjs apps/kafyj.zy.huawei
```

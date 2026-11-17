import fs from 'node:fs';
import { clickText, assertText, screenshot } from './device-driver.mjs';
const results = [];
for (const [tab, expected, name] of [
  ['首页', '年画新世界', 'home'], ['年画馆', '看见传统', 'gallery'],
  ['创作', '创意工坊', 'creative'], ['乐园', '互动乐园', 'playground'], ['我的', '年画体验者', 'mine']
]) {
  await clickText(tab);
  await assertText(expected);
  await screenshot(name);
  results.push({ tab, status: 'pass' });
  console.log(`PASS emulator navigation: ${tab}`);
}
fs.writeFileSync(new URL('../docs/validation/device-navigation.json', import.meta.url), JSON.stringify({ checkedAt: new Date().toISOString(), target: 'HarmonyOS API 24 emulator', results }, null, 2));

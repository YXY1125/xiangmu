import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const app = fs.realpathSync(new URL('../app', import.meta.url));
const profilePath = path.join(app, 'build-profile.json5');
const original = fs.readFileSync(profilePath);
const originalHash = createHash('sha256').update(original).digest('hex');
const originalConfig = JSON.parse(original.toString('utf8'));
const useProjectSigning = process.argv.includes('--use-project-signing');
if (!useProjectSigning && (originalConfig.app?.signingConfigs || []).some((config) => config.material?.storePassword || config.material?.keyPassword)) {
  throw new Error('Project configuration contains signing credentials; remove local credential entries before packaging');
}
const credentialSource = process.env.HARMONY_SIGNING_CONFIG_SOURCE;
if (!useProjectSigning && !credentialSource) throw new Error('HARMONY_SIGNING_CONFIG_SOURCE must point to an existing protected local signing configuration');
let existing;
try { existing = useProjectSigning ? originalConfig : JSON.parse(fs.readFileSync(credentialSource, 'utf8')); }
catch { throw new Error('Cannot read protected signing configuration; contents suppressed'); }
const material = existing.app?.signingConfigs?.find((config) =>
  path.resolve(config.material?.storeFile || '').toLowerCase() === path.resolve('D:/profile/huawei/huawei.p12').toLowerCase())?.material;
if (!material?.storePassword || !material?.keyPassword) throw new Error('Matching existing signing credentials unavailable');
if (useProjectSigning) {
  const normalize = (value) => path.resolve(value || '').toLowerCase();
  if (normalize(material.profile) !== normalize('D:/profile/geren/hljszfxxkj/zxznh.xcl.huaweiRelease.p7b') ||
      normalize(material.certpath) !== normalize('D:/profile/geren/hljszfxxkj/huawei.cer')) {
    throw new Error('Existing project signing profile or certificate does not match this app');
  }
}
const generated = originalConfig;
generated.app.signingConfigs = [{ name: 'default', type: 'HarmonyOS', material: {
  ...material,
  certpath: 'D:/profile/geren/hljszfxxkj/huawei.cer',
  profile: 'D:/profile/geren/hljszfxxkj/zxznh.xcl.huaweiRelease.p7b',
  storeFile: 'D:/profile/huawei/huawei.p12'
} }];

let result;
try {
  if (!useProjectSigning) fs.writeFileSync(profilePath, JSON.stringify(generated, null, 2));
  result = spawnSync(process.execPath, ['D:/DevEco Studio/tools/hvigor/bin/hvigorw.js',
    'assembleApp', '--mode', 'project', '-p', 'product=default', '-p', 'buildMode=release', '--no-daemon'
  ], { cwd: app, shell: false, encoding: 'utf8', windowsHide: true, timeout: 300000, maxBuffer: 8 * 1024 * 1024 });
} finally {
  if (!useProjectSigning) fs.writeFileSync(profilePath, original);
}
if (createHash('sha256').update(fs.readFileSync(profilePath)).digest('hex') !== originalHash) throw new Error('Build configuration restoration failed');
let output = `${result.stdout || ''}\n${result.stderr || ''}`;
for (const secret of [material.storePassword, material.keyPassword]) output = output.split(secret).join('[REDACTED]');
output = output.replace(/((?:storePassword|keyPassword)\s*[:=]\s*)\S+/gi, '$1[REDACTED]');
process.stdout.write(output);
console.log(useProjectSigning ? 'Existing local signing configuration preserved byte-for-byte; credential values suppressed' :
  'Local signing configuration restored; credentials were not retained in project files');
process.exitCode = result.status || (result.error ? 1 : 0);

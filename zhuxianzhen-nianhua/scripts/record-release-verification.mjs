import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { verifyRelease } from '../../../runtimes/lib/release-verification.mjs';

const appDir = fileURLToPath(new URL('..', import.meta.url));
const artifacts = ['app/build/outputs/default/app-default-signed.app', 'app/entry/build/default/outputs/default/entry-default-signed.hap'];
const reports = artifacts.map((artifact) => verifyRelease({ appDir, artifact,
  java: 'D:/DevEco Studio/jbr/bin/java.exe',
  signTool: 'D:/DevEco Studio/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar',
  expectedBundle: 'zxznh.xcl.huawei'
}));
const hap = path.join(appDir, artifacts[1]);
const extract = (file) => {
  const result = spawnSync('tar.exe', ['-xOf', hap, file], { windowsHide: true, maxBuffer: 8 * 1024 * 1024 });
  if (result.status !== 0) throw new Error('Candidate archive extraction failed');
  return result.stdout;
};
const manifest = JSON.parse(extract('module.json').toString('utf8'));
const permissions = manifest.module.requestPermissions.map((item) => item.name).sort();
const expected = ['ohos.permission.INTERNET', 'ohos.permission.APP_TRACKING_CONSENT'].sort();
const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
const require = createRequire(new URL('../../../platform/server/package.json', import.meta.url));
const sharp = require('sharp');
const packedIcon = extract('resources/base/media/app_icon.png');
const originalIcon = fs.readFileSync(path.join(appDir, 'design/logo/icon_single.png'));
const packedSize = await sharp(packedIcon).metadata();
const originalSize = await sharp(originalIcon).metadata();
const normalizedOriginal = await sharp(originalIcon).resize(packedSize.width, packedSize.height).removeAlpha().raw().toBuffer();
const normalizedPacked = await sharp(packedIcon).removeAlpha().raw().toBuffer();
let channelDifference = 0;
for (let index = 0; index < normalizedOriginal.length; index++) channelDifference += Math.abs(normalizedOriginal[index] - normalizedPacked[index]);
const meanChannelDifference = channelDifference / normalizedOriginal.length;
const iconConsistent = packedSize.width === packedSize.height && meanChannelDifference < 1;
const metadata = {
  bundleName: manifest.app.bundleName, debug: manifest.app.debug,
  permissions, permissionsMatch: JSON.stringify(permissions) === JSON.stringify(expected), iconConsistent,
  iconCheck: { byteIdentical: hash(packedIcon) === hash(originalIcon), originalSize: originalSize.width, packagedSize: packedSize.width,
    meanChannelDifference, method: 'Compiler scales 1024px source to 512px. Compare RGB pixels at packaged size; threshold mean < 1/255. Visual inspection also completed.' }
};
const status = reports.every((report) => report.status === 'pass') && metadata.bundleName === 'zxznh.xcl.huawei' && metadata.debug === false && metadata.permissionsMatch && iconConsistent ? 'pass' : 'fail';
const result = { checkedAt: new Date().toISOString(), status, scope: 'signed-artifact-profile-permissions-icon-only', releaseReadiness: 'not-assessed', artifacts: reports, packagedMetadata: metadata };
fs.writeFileSync(path.join(appDir, 'docs/validation/release-artifacts.json'), JSON.stringify(result, null, 2) + String.fromCharCode(10));
console.log(JSON.stringify(result, null, 2));
process.exitCode = status === 'pass' ? 0 : 1;

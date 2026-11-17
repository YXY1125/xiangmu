import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {databaseConnection} from '../src/database-config.mjs';
test('protected database file loads only the scoped non-superuser and never exposes secret parsing diagnostics',async t=>{
  const dir=await fs.mkdtemp(path.join(os.tmpdir(),'thwkb-config-test-')),file=path.join(dir,'database.json');
  t.after(async()=>{const real=await fs.realpath(dir),parent=await fs.realpath(os.tmpdir());assert.ok(path.dirname(real)===parent&&path.basename(real).startsWith('thwkb-config-test-'));await fs.rm(real,{recursive:true,force:true});});
  const secret=crypto.randomBytes(32).toString('hex'),config={host:'127.0.0.1',port:55426,database:'thwkb_zh_huawei',user:'thwkb_app',password:secret};
  await fs.writeFile(file,JSON.stringify(config),{mode:0o600});
  const uri=new URL(await databaseConnection({configFile:file}));assert.equal(uri.username,'thwkb_app');assert.equal(uri.password,secret);
  await fs.writeFile(file,JSON.stringify({...config,user:'postgres'}));await assert.rejects(databaseConnection({configFile:file}),e=>!e.message.includes(secret));
  await fs.writeFile(file,'{"password":"'+secret+'", broken');await assert.rejects(databaseConnection({configFile:file}),e=>!e.message.includes(secret)&&e.message.includes('configuration'));
});
test('external database URLs require verified TLS and missing configuration never downgrades to files',async()=>{
  await assert.rejects(databaseConnection({}),/configuration/);
  await assert.rejects(databaseConnection({connectionString:'postgresql://unit:unit@remote.example/db'}),/configuration/);
  assert.ok((await databaseConnection({connectionString:'postgresql://unit:unit@remote.example/db?sslmode=verify-full'})).includes('verify-full'));
});

import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../platform/server/package.json', import.meta.url));
const ts = require('typescript');
const values = new Map();
const appState = new Map();
let beforeRead = async () => {};
const uploads = [];
globalThis.AppStorage = { get: (key) => appState.get(key === 'currentUserId' ? 'currentUsername' : key), setOrCreate: (key, value) => appState.set(key, value) };
globalThis.storageTestDependencies = {
  preferences: { getPreferences: async () => ({
    get: async (key, fallback) => { await beforeRead(); return values.get(key) ?? fallback; },
    put: async (key, value) => { values.set(key, value); }, flush: async () => {}
  }) },
  CloudSyncService: Object.fromEntries(['favorite', 'artwork', 'game', 'learning', 'browsing'].map((name) => [name, async () => uploads.push({ name, username: appState.get('currentUsername') })]))
};
const source = fs.readFileSync(new URL('../app/entry/src/main/ets/services/LocalDataStore.ets', import.meta.url), 'utf8').replace(/^import .*$/gm, '');
const syncModels = fs.readFileSync(new URL('../app/entry/src/main/ets/models/SyncModels.ets', import.meta.url), 'utf8').replace(/^import .*$/gm, '');
const compiled = ts.transpileModule(`const {preferences, CloudSyncService} = globalThis.storageTestDependencies;\n${syncModels}\n${source}`, {
  compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 }
}).outputText;
const { LocalDataStore } = await import(`data:text/javascript;base64,${Buffer.from(compiled).toString('base64')}`);
await LocalDataStore.init({});

test('anonymous guest and a registered username named guest never share data', async () => {
  appState.set('currentUsername', '');
  await LocalDataStore.toggleFavorite('anonymous-favorite');
  appState.set('currentUsername', 'guest');
  assert.deepEqual(await LocalDataStore.favorites(), []);
  await LocalDataStore.toggleFavorite('registered-favorite');
  appState.set('currentUsername', '');
  assert.deepEqual(await LocalDataStore.favorites(), ['anonymous-favorite']);
});

test('concurrent read-modify-write operations preserve both favorites', async () => {
  appState.set('currentUsername', 'parallel-user');
  await Promise.all([LocalDataStore.toggleFavorite('first'), LocalDataStore.toggleFavorite('second')]);
  assert.deepEqual(await LocalDataStore.favorites(), ['first', 'second']);
});

test('an account switch during an awaited save cannot write or upload as the new user', async () => {
  appState.set('currentUsername', 'user-a');
  let release;
  let readStarted;
  const started = new Promise((resolve) => { readStarted = resolve; });
  beforeRead = async () => { readStarted(); await new Promise((resolve) => { release = resolve; }); };
  const count = uploads.length;
  const save = LocalDataStore.saveArtwork({ artworkId: 'owned-by-a', layers: [], textObjects: [] });
  await started;
  appState.set('currentUsername', 'user-b');
  beforeRead = async () => {};
  release();
  await save;
  assert.deepEqual(await LocalDataStore.artworks(), []);
  assert.equal(uploads.length, count);
  appState.set('currentUsername', 'user-a');
  const restored = await LocalDataStore.artworks();
  assert.equal(restored[0].artworkId, 'owned-by-a');
  assert.equal(restored[0].ownerId, 'zxznh:user:user-a');
});

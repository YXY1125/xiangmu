import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../platform/server/package.json', import.meta.url));
const ts = require('typescript');
const read = (file) => fs.readFileSync(new URL('../app/entry/src/main/ets/' + file, import.meta.url), 'utf8').replace(/^import .*$/gm, '');
const source = read('models/CultureModels.ets') + '\n' + read('models/SyncModels.ets') + '\n' + read('services/LocalDataStore.ets');
let sequence = 0;
async function makeWorld(storage = new Map(), remote = new Map()) {
  const state = new Map([['currentUserId', 'a'], ['accessToken', 'token-a']]);
  const world = { state, storage, remote, online: false, beforePost: async () => {}, beforeGet: async () => {} };
  globalThis.AppStorage = { get: (key) => state.get(key), setOrCreate: (key, value) => state.set(key, value) };
  globalThis.syncTestDeps = {
    preferences: { getPreferences: async () => ({ get: async (key, fallback) => storage.get(key) ?? fallback, put: async (key, value) => storage.set(key, value), flush: async () => {} }) },
    HttpClient: {
      post: async (path, payload) => {
        const owner = state.get('currentUserId');
        await world.beforePost();
        if (!world.online) return { code: 50001, message: 'offline' };
        const key = owner + ':' + path.split('/').at(-1);
        const rows = remote.get(key) ?? [];
        const index = rows.findIndex((item) => item.id === payload.id);
        if (index >= 0) rows[index] = structuredClone(payload); else rows.push(structuredClone(payload));
        remote.set(key, rows);
        return { code: 0 };
      },
      get: async (path) => {
        const owner = state.get('currentUserId');
        await world.beforeGet();
        if (!world.online) return { code: 50001, message: 'offline' };
        return { code: 0, data: { items: structuredClone(remote.get(owner + ':' + path.split('/').at(-1)) ?? []) } };
      }
    }
  };
  const compiled = ts.transpileModule('const {preferences, HttpClient} = globalThis.syncTestDeps;\n' + source + '\n//instance-' + sequence++, { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } }).outputText;
  world.store = (await import('data:text/javascript;base64,' + Buffer.from(compiled).toString('base64'))).LocalDataStore;
  await world.store.init({});
  return world;
}
async function settle(world) {
  for (let attempt = 0; attempt < 50; attempt++) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    if (world.state.get('syncStatus') !== '正在同步当前账号…') return;
  }
  throw new Error('Synchronization did not settle');
}
const queue = (world, owner = 'a') => JSON.parse(world.storage.get(JSON.stringify(['zxznh:user:' + owner, 'syncOutbox'])) ?? '[]');

test('offline writes survive process recreation and drain idempotently on reconnect', async () => {
  let world = await makeWorld();
  await world.store.toggleFavorite('character:qin-xiaojiang');
  await settle(world);
  assert.equal(queue(world).length, 1);
  world = await makeWorld(world.storage, world.remote);
  world.online = true;
  assert.equal(await world.store.synchronize(), true);
  assert.equal(queue(world).length, 0);
  assert.deepEqual(await world.store.favorites(), ['character:qin-xiaojiang']);
  await world.store.synchronize();
  assert.equal(world.remote.get('a:favorites').length, 1);
});

test('acknowledging an in-flight version cannot discard a newer favorite change', async () => {
  const world = await makeWorld();
  world.online = true;
  let release;
  let started;
  const inFlight = new Promise((resolve) => { started = resolve; });
  world.beforePost = async () => { started(); await new Promise((resolve) => { release = resolve; }); };
  await world.store.toggleFavorite('article:origin');
  await inFlight;
  await world.store.toggleFavorite('article:origin');
  assert.equal(queue(world)[0].version, 2);
  world.beforePost = async () => {};
  release();
  await settle(world);
  assert.equal(queue(world).length, 1);
  await world.store.synchronize();
  assert.equal(world.remote.get('a:favorites')[0].active, false);
  assert.deepEqual(await world.store.favorites(), []);
});

test('a late private pull after account switch never enters the new account namespace', async () => {
  const world = await makeWorld();
  world.online = true;
  world.remote.set('a:favorites', [{ id: 'favorite-a', targetId: 'secret-a', active: true }]);
  let release;
  let started;
  const inFlight = new Promise((resolve) => { started = resolve; });
  world.beforeGet = async () => { started(); await new Promise((resolve) => { release = resolve; }); };
  const sync = world.store.synchronize();
  await inFlight;
  world.state.set('currentUserId', 'b'); world.state.set('accessToken', 'token-b');
  world.beforeGet = async () => {}; release();
  assert.equal(await sync, false);
  assert.deepEqual(await world.store.favorites(), []);
  await world.store.synchronize();
  assert.deepEqual(await world.store.favorites(), []);
});

test('cloud artwork restores layers without trusting another device filesystem paths', async () => {
  const world = await makeWorld();
  world.online = true;
  world.remote.set('a:artworks', [{ id: 'server-a', artworkId: 'work-a', title: '恢复作品', clientCreatedAt: 1000, clientUpdatedAt: 2000, canvasWidth: 900, canvasHeight: 1200, backgroundId: 'bg_plum_paper', layers: [{ layerId: 'layer-a', x: 20, y: 30, rotation: 15 }], textObjects: [], exportPath: '/another/device/file.png', thumbnailPath: '/another/device/thumb.png' }]);
  await world.store.synchronize();
  const work = (await world.store.artworks())[0];
  assert.equal(work.layers[0].rotation, 15);
  assert.equal(work.backgroundId, 'bg_plum_paper');
  assert.equal(work.createdAt, 1000);
  assert.equal(work.updatedAt, 2000);
  assert.equal(work.exportPath, '');
  assert.equal(work.thumbnailPath, '');
});

test('cloud pull publishes a local revision and refreshes all four personal-space datasets', async () => {
  const world = await makeWorld();
  world.online = true;
  world.remote.set('a:favorites', [{ id: 'favorite-a', targetId: 'character:qin-xiaojiang', active: true }]);
  world.remote.set('a:artworks', [{ artworkId: 'cloud-work', clientCreatedAt: 1, clientUpdatedAt: 2, layers: [], textObjects: [] }]);
  world.remote.set('a:game-records', [{ recordId: 'cloud-round', score: 100 }]);
  world.remote.set('a:learning-records', [{ articleId: 'origin' }]);
  const before = world.state.get('businessDataRevision');
  assert.equal(await world.store.synchronize(), true);
  assert.equal(world.state.get('businessDataRevision'), before + 1);
  const snapshot = await world.store.mySpaceSnapshot();
  assert.deepEqual([snapshot.favoriteIds.length, snapshot.artworks.length, snapshot.gameRecords.length, snapshot.learningIds.length], [1, 1, 1, 1]);
});

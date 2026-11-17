import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../platform/server/package.json', import.meta.url));
const ts = require('typescript');
const read = (file) => fs.readFileSync(new URL('../app/entry/src/main/ets/' + file, import.meta.url), 'utf8').replace(/^import .*$/gm, '');
const page = read('pages/MinePage.ets');
const refreshMethods = page.slice(page.indexOf('  private reload(): void {'), page.indexOf('  build() {'));
let sequence = 0;
async function fixture(storage = new Map()) {
  const state = new Map();
  let listener = () => {};
  const world = { state, storage, flushFails: false, readFails: false, notifications: 0, beforeRead: async () => {} };
  globalThis.AppStorage = {
    get: (key) => state.get(key),
    setOrCreate: (key, value) => {
      const old = state.get(key); state.set(key, value);
      if (key === 'businessDataRevision' && old !== value) { world.notifications++; listener(); }
    }
  };
  globalThis.mineTestDeps = {
    preferences: { getPreferences: async () => ({
      get: async (key, fallback) => { await world.beforeRead(); if (world.readFails) throw new Error('read failure'); return storage.get(key) ?? fallback; },
      put: async (key, value) => { storage.set(key, value); },
      flush: async () => { if (world.flushFails) throw new Error('flush failure'); }
    }) },
    HttpClient: { post: async () => ({ code: 50001, message: 'offline' }), get: async () => ({ code: 50001, message: 'offline' }) }
  };
  const code = ts.transpileModule('const {preferences, HttpClient} = globalThis.mineTestDeps;\n' +
    read('models/CultureModels.ets') + '\n' + read('models/SyncModels.ets') + '\n' + read('services/LocalDataStore.ets') +
    '\nexport class TestMine { visible = true; reloadVersion = 0; favorites = 0; favoriteIds = []; artworks = []; records = []; learned = 0; learnedIds = []; statisticsMessage = "";\n' + refreshMethods + '\n}\n//fixture-' + sequence++,
    { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } }).outputText;
  const module = await import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'));
  world.store = module.LocalDataStore;
  await world.store.init({});
  world.mine = new module.TestMine();
  listener = () => world.mine.onBusinessDataChanged();
  world.mine.reload();
  await settle(world);
  return world;
}
async function settle(world) {
  await world.store.mySpaceSnapshot();
  await new Promise((resolve) => setTimeout(resolve, 0));
}
const counts = (mine) => [mine.favorites, mine.artworks.length, mine.records.length, mine.learned];

test('guest statistics update for favorite, creation, game and learning without cloud sync', async () => {
  const world = await fixture();
  assert.deepEqual(counts(world.mine), [0, 0, 0, 0]);
  await world.store.toggleFavorite('character:qin-xiaojiang'); await settle(world);
  assert.deepEqual(counts(world.mine), [1, 0, 0, 0]);
  await world.store.saveArtwork({ artworkId: 'work-one', title: '第一件', layers: [], textObjects: [], createdAt: 1, updatedAt: 1 }); await settle(world);
  assert.deepEqual(counts(world.mine), [1, 1, 0, 0]);
  await world.store.saveGameRecord({ recordId: 'round-one', gameId: 'quiz' }); await settle(world);
  assert.deepEqual(counts(world.mine), [1, 1, 1, 0]);
  await world.store.markLearned('origin'); await settle(world);
  assert.deepEqual(counts(world.mine), [1, 1, 1, 1]);
  await world.store.toggleFavorite('character:qin-xiaojiang'); await settle(world);
  assert.deepEqual(counts(world.mine), [0, 1, 1, 1]);
});

test('re-editing, retried results and repeated reading do not inflate statistics', async () => {
  const world = await fixture();
  const work = { artworkId: 'same-work', title: '初稿', layers: [], textObjects: [], createdAt: 1, updatedAt: 1 };
  await world.store.saveArtwork(work);
  await world.store.saveArtwork({ ...work, title: '修改后', updatedAt: 2 });
  await world.store.saveGameRecord({ recordId: 'same-round', score: 1 });
  await world.store.saveGameRecord({ recordId: 'same-round', score: 2 });
  await world.store.markLearned('origin'); await world.store.markLearned('origin');
  await settle(world);
  assert.deepEqual(counts(world.mine), [0, 1, 1, 1]);
  assert.equal(world.mine.artworks[0].title, '修改后');
  assert.equal(world.mine.records[0].score, 2);
});

test('a recreated page restores the same persisted statistics', async () => {
  let world = await fixture();
  await world.store.toggleFavorite('article:origin');
  await world.store.markLearned('origin');
  await settle(world);
  world = await fixture(world.storage);
  assert.deepEqual(counts(world.mine), [1, 0, 0, 1]);
});

test('failed persistence does not announce a successful change; read failure retains visible counts', async () => {
  const world = await fixture();
  await world.store.toggleFavorite('article:origin'); await settle(world);
  const revisions = world.notifications;
  world.flushFails = true;
  await assert.rejects(world.store.saveGameRecord({ recordId: 'failed' }));
  assert.equal(world.notifications, revisions);
  world.flushFails = false;
  world.readFails = true;
  world.mine.reload();
  await new Promise((resolve) => setTimeout(resolve, 5));
  assert.equal(world.mine.favorites, 1);
  assert.match(world.mine.statisticsMessage, /读取失败/);
});

test('late snapshots and writes from account A never overwrite current B statistics', async () => {
  const world = await fixture();
  world.state.set('currentUserId', 'a');
  await world.store.toggleFavorite('owned-by-a'); await settle(world);
  assert.equal(world.mine.favorites, 1);
  let release;
  let started;
  const inFlight = new Promise((resolve) => { started = resolve; });
  world.beforeRead = async () => { started(); await new Promise((resolve) => { release = resolve; }); };
  world.mine.reload();
  await inFlight;
  world.state.set('currentUserId', 'b');
  world.mine.onOwnerChanged();
  world.beforeRead = async () => {};
  release();
  await settle(world);
  assert.deepEqual(counts(world.mine), [0, 0, 0, 0]);
  world.state.set('currentUserId', 'a'); world.mine.onOwnerChanged(); await settle(world);
  assert.equal(world.mine.favorites, 1);
});

test('an older refresh completion cannot overwrite a newer page snapshot', async () => {
  const world = await fixture();
  const realSnapshot = world.store.mySpaceSnapshot;
  let finishOld;
  world.store.mySpaceSnapshot = () => new Promise((resolve) => { finishOld = resolve; });
  world.mine.reload();
  world.store.mySpaceSnapshot = async () => ({ ownerId: world.store.ownerId(), favoriteIds: ['new-a', 'new-b'], artworks: [], gameRecords: [], learningIds: [] });
  world.mine.reload();
  await new Promise((resolve) => setTimeout(resolve, 0));
  finishOld({ ownerId: world.store.ownerId(), favoriteIds: [], artworks: [], gameRecords: [], learningIds: [] });
  await new Promise((resolve) => setTimeout(resolve, 0));
  assert.equal(world.mine.favorites, 2);
  world.store.mySpaceSnapshot = realSnapshot;
});

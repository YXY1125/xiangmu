import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { createCoffeeService } from '../runtime/core.mjs';
import { createCoffeeHttpServer } from '../runtime/server.mjs';

const TEST_PASSWORD = ['StrongPass', '#', '2026'].join('');

function setup() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'coffee-lab-'));
  const service = createCoffeeService({ file: path.join(dir, 'runtime.json'), mediaDir: path.join(dir, 'media'), secret: crypto.randomBytes(32).toString('hex') });
  return { dir, service };
}

function registration(username, phone) {
  return {
    username,
    password: TEST_PASSWORD,
    realName: username,
    phone,
    agreementVersion: '2026-11-10-draft',
    privacyVersion: '2026-11-10-draft',
    consentAcceptedAt: '2026-11-10T08:00:00.000Z',
  };
}

test('registration hashes password and records active consent', () => {
  const { dir, service } = setup();
  const result = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  assert.equal(result.ok, true);
  const state = service.load();
  assert.equal(state.users.length, 1);
  assert.notEqual(state.users[0].passwordHash, TEST_PASSWORD);
  assert.equal(state.users[0].consent.agreementVersion, '2026-11-10-draft');
  fs.rmSync(dir, { recursive: true, force: true });
});

test('registration is rejected without explicit protocol consent', () => {
  const { dir, service } = setup();
  const input = registration('alice', '13800000001');
  delete input.consentAcceptedAt;
  assert.equal(service.register(input, 'kafyj.zy.huawei').ok, false);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('signed session derives userId and isolates records between users', () => {
  const { dir, service } = setup();
  const alice = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  const bob = service.register(registration('bob', '13800000002'), 'kafyj.zy.huawei');
  const aliceSession = service.authenticate(alice.accessToken, 'kafyj.zy.huawei');
  const bobSession = service.authenticate(bob.accessToken, 'kafyj.zy.huawei');
  const created = service.createRecord(aliceSession, 'brew', { coffeeName: 'Ethiopia', dose: 15, water: 225 });
  assert.equal(created.ok, true);
  assert.equal(service.listRecords(aliceSession, 'brew').length, 1);
  assert.equal(service.listRecords(bobSession, 'brew').length, 0);
  assert.notEqual(aliceSession.userId, bobSession.userId);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('business records are archived and versioned instead of deleted', () => {
  const { dir, service } = setup();
  const user = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  const session = service.authenticate(user.accessToken, 'kafyj.zy.huawei');
  const created = service.createRecord(session, 'recipe', { name: 'V60' });
  const archived = service.archiveRecord(session, created.record.id);
  assert.equal(archived.ok, true);
  assert.equal(archived.record.status, 'archived');
  assert.equal(archived.record.version, 2);
  assert.equal(service.listRecords(session, 'recipe').length, 1);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('growth uses persisted behavior and does not count page opens', () => {
  const { dir, service } = setup();
  const user = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  const session = service.authenticate(user.accessToken, 'kafyj.zy.huawei');
  service.createRecord(session, 'learning', { knowledgeId: 'origin-ethiopia' });
  service.createRecord(session, 'brew', { coffeeName: 'Ethiopia' });
  service.createRecord(session, 'evaluation', { overall: 4 });
  assert.deepEqual(service.growth(session), {
    learningCount: 1,
    brewCount: 1,
    recipeCount: 0,
    evaluationCount: 1,
    favoriteCount: 0,
    recipeFavoriteCount: 0,
    checkInCount: 0,
    experience: 32,
  });
  fs.rmSync(dir, { recursive: true, force: true });
});

test('account closure anonymizes identity, archives records and revokes the session', () => {
  const { dir, service } = setup();
  const user = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  const session = service.authenticate(user.accessToken, 'kafyj.zy.huawei');
  service.createRecord(session, 'brew', { coffeeName: 'Ethiopia' });
  const closed = service.closeAccount(session);
  assert.equal(closed.ok, true);
  assert.equal(service.authenticate(user.accessToken, 'kafyj.zy.huawei'), null);
  const state = service.load();
  assert.equal(state.users[0].realName, '');
  assert.equal(state.users[0].phone, '');
  assert.equal(state.users[0].status, 'closed');
  assert.equal(state.profiles[0].nickname, '');
  assert.equal(state.profiles[0].archivedAt.length > 0, true);
  assert.equal(state.records[0].status, 'archived');
  fs.rmSync(dir, { recursive: true, force: true });
});

test('learning and favorites are idempotent so realtime counters do not inflate', () => {
  const { dir, service } = setup();
  const user = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  const session = service.authenticate(user.accessToken, 'kafyj.zy.huawei');
  service.createRecord(session, 'learning', { knowledgeId: 'origin-ethiopia' });
  service.createRecord(session, 'learning', { knowledgeId: 'origin-ethiopia' });
  service.createRecord(session, 'favorite', { targetType: 'knowledge', targetId: 'origin-ethiopia' });
  service.createRecord(session, 'favorite', { targetType: 'knowledge', targetId: 'origin-ethiopia' });
  assert.equal(service.listRecords(session, 'learning').length, 1);
  assert.equal(service.listRecords(session, 'favorite').length, 1);
  assert.equal(service.growth(session).learningCount, 1);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('evaluation statistics are calculated from persisted user records only', () => {
  const { dir, service } = setup();
  const alice = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  const bob = service.register(registration('bob', '13800000002'), 'kafyj.zy.huawei');
  const aliceSession = service.authenticate(alice.accessToken, 'kafyj.zy.huawei');
  const bobSession = service.authenticate(bob.accessToken, 'kafyj.zy.huawei');
  service.createRecord(aliceSession, 'evaluation', { scores: { overall: 5, aroma: 4 }, tags: ['花香'] });
  service.createRecord(aliceSession, 'evaluation', { scores: { overall: 3, aroma: 2 }, tags: ['花香', '茶感'] });
  service.createRecord(bobSession, 'evaluation', { scores: { overall: 1 }, tags: ['坚果'] });
  const stats = service.evaluationStats(aliceSession);
  assert.equal(stats.count, 2);
  assert.equal(stats.averages.overall, 4);
  assert.deepEqual(stats.tags[0], { name: '花香', count: 2 });
  fs.rmSync(dir, { recursive: true, force: true });
});

test('record edits create a new version and preserve the previous audit row', () => {
  const { dir, service } = setup();
  const user = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  const session = service.authenticate(user.accessToken, 'kafyj.zy.huawei');
  const first = service.createRecord(session, 'recipe', { name: 'V60', ratio: 15 });
  const second = service.versionRecord(session, first.record.id, { ratio: 16 });
  assert.equal(second.ok, true);
  assert.equal(second.record.version, 2);
  assert.equal(second.record.parentVersionId, first.record.id);
  const rows = service.listRecords(session, 'recipe');
  assert.equal(rows.length, 2);
  assert.equal(rows[0].status, 'superseded');
  assert.equal(rows[1].payload.ratio, 16);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('profile reads and writes are scoped to the authenticated user', () => {
  const { dir, service } = setup();
  const alice = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  const bob = service.register(registration('bob', '13800000002'), 'kafyj.zy.huawei');
  const aliceSession = service.authenticate(alice.accessToken, 'kafyj.zy.huawei');
  const bobSession = service.authenticate(bob.accessToken, 'kafyj.zy.huawei');
  service.updateProfile(aliceSession, { nickname: '手冲练习者', bio: '记录每一次调整', interestDirections: ['手冲'] });
  assert.equal(service.getProfile(aliceSession).nickname, '手冲练习者');
  assert.equal(service.getProfile(bobSession).nickname, 'bob');
  fs.rmSync(dir, { recursive: true, force: true });
});

test('growth counters reflect every persisted write and count only the active recipe version', () => {
  const { dir, service } = setup();
  const user = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  const session = service.authenticate(user.accessToken, 'kafyj.zy.huawei');

  assert.deepEqual(service.growth(session), {
    learningCount: 0,
    brewCount: 0,
    recipeCount: 0,
    evaluationCount: 0,
    favoriteCount: 0,
    recipeFavoriteCount: 0,
    checkInCount: 0,
    experience: 0,
  });

  service.createRecord(session, 'learning', { knowledgeId: 'flavor-acidity' });
  assert.equal(service.growth(session).experience, 5);

  service.createRecord(session, 'brew', { coffeeName: 'Kenya AA' });
  assert.deepEqual(service.growth(session), {
    learningCount: 1,
    brewCount: 1,
    recipeCount: 0,
    evaluationCount: 0,
    favoriteCount: 0,
    recipeFavoriteCount: 0,
    checkInCount: 0,
    experience: 17,
  });

  const recipe = service.createRecord(session, 'recipe', { name: 'V60', ratio: 15 });
  service.versionRecord(session, recipe.record.id, { ratio: 16 });
  assert.equal(service.growth(session).recipeCount, 1);

  service.createRecord(session, 'evaluation', { scores: { overall: 4 }, tags: ['柑橘'] });
  service.createRecord(session, 'favorite', { targetType: 'recipe', targetId: 'v60-balanced' });
  service.createRecord(session, 'checkin', {});
  service.createRecord(session, 'checkin', {});
  assert.deepEqual(service.growth(session), {
    learningCount: 1,
    brewCount: 1,
    recipeCount: 1,
    evaluationCount: 1,
    favoriteCount: 1,
    recipeFavoriteCount: 1,
    checkInCount: 1,
    experience: 43,
  });
  assert.equal(service.achievements(session).find((item) => item.id === 'recipe-collector').achieved, true);

  fs.rmSync(dir, { recursive: true, force: true });
});

test('image upload validates content and stores it inside the authenticated owner directory', () => {
  const { dir, service } = setup();
  const user = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  const session = service.authenticate(user.accessToken, 'kafyj.zy.huawei');
  const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
  const result = service.saveImage(session, { mimeType: 'image/png', dataBase64: png.toString('base64') });
  assert.equal(result.ok, true);
  assert.equal(result.sizeBytes, png.length);
  assert.equal(fs.existsSync(path.join(dir, 'media', 'kafyj.zy.huawei', session.userId, result.key)), true);
  assert.deepEqual(service.readImage(session, result.key).bytes, png);
  const bob = service.register(registration('bob', '13800000002'), 'kafyj.zy.huawei');
  const bobSession = service.authenticate(bob.accessToken, 'kafyj.zy.huawei');
  assert.equal(service.readImage(bobSession, result.key), null);
  assert.equal(service.saveImage(session, { mimeType: 'image/png', dataBase64: Buffer.from('not-a-png').toString('base64') }).ok, false);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('activity statistics are derived from active user records and update after every write', () => {
  const { dir, service } = setup();
  const alice = service.register(registration('alice', '13800000001'), 'kafyj.zy.huawei');
  const bob = service.register(registration('bob', '13800000002'), 'kafyj.zy.huawei');
  const aliceSession = service.authenticate(alice.accessToken, 'kafyj.zy.huawei');
  const bobSession = service.authenticate(bob.accessToken, 'kafyj.zy.huawei');
  service.createRecord(aliceSession, 'brew', { coffeeName: 'V60', method: '手冲' });
  service.createRecord(aliceSession, 'brew', { coffeeName: 'French press', method: '法压壶' });
  service.createRecord(aliceSession, 'evaluation', { scores: { overall: 4 } });
  service.createRecord(bobSession, 'brew', { coffeeName: 'Espresso', method: '意式' });
  const stats = service.activityStats(aliceSession);
  assert.equal(stats.days.length, 7);
  assert.equal(stats.days[6].brewCount, 2);
  assert.equal(stats.days[6].evaluationCount, 1);
  assert.deepEqual(stats.methods, [{ name: '手冲', count: 1 }, { name: '法压壶', count: 1 }]);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('HTTP contract closes register, write, realtime stats and authenticated image flow', async () => {
  const { dir, service } = setup();
  const server = createCoffeeHttpServer(service);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const address = server.address();
    const base = `http://127.0.0.1:${address.port}/api/v1`;
    const common = { 'Content-Type': 'application/json', 'X-Tenant-Id': 'kafyj.zy.huawei' };
    const registered = await fetch(`${base}/auth/register`, { method: 'POST', headers: common, body: JSON.stringify(registration('alice', '13800000001')) }).then((response) => response.json());
    assert.equal(registered.code, 0);
    const headers = { ...common, Authorization: `Bearer ${registered.data.accessToken}` };
    const brew = await fetch(`${base}/biz/kafyj.zy.huawei/me/brewing-records`, { method: 'POST', headers, body: JSON.stringify({ coffeeName: 'HTTP V60', method: '手冲' }) }).then((response) => response.json());
    assert.equal(brew.code, 0);
    const growth = await fetch(`${base}/biz/kafyj.zy.huawei/me/growth`, { headers }).then((response) => response.json());
    assert.equal(growth.data.brewCount, 1);
    const activity = await fetch(`${base}/biz/kafyj.zy.huawei/me/activity-stats`, { headers }).then((response) => response.json());
    assert.equal(activity.data.days[6].brewCount, 1);
    const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
    const uploaded = await fetch(`${base}/biz/kafyj.zy.huawei/media/images`, { method: 'POST', headers, body: JSON.stringify({ mimeType: 'image/png', dataBase64: png.toString('base64') }) }).then((response) => response.json());
    assert.equal(uploaded.code, 0);
    const imageResponse = await fetch(`${base}/biz/kafyj.zy.huawei/media/images/${uploaded.data.key}`, { headers });
    assert.equal(imageResponse.status, 200);
    assert.equal(imageResponse.headers.get('content-type'), 'image/png');
    assert.deepEqual(Buffer.from(await imageResponse.arrayBuffer()), png);
  } finally {
    await new Promise((resolve) => server.close(resolve));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

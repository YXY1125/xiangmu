import fs from 'node:fs';
import path from 'node:path';
import { createHmac, randomBytes, randomUUID, scryptSync, timingSafeEqual } from 'node:crypto';

const EMPTY_STATE = { users: [], records: [], profiles: [] };

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function normalizeText(value, max = 240) {
  return String(value ?? '').trim().slice(0, max);
}

function hashPassword(password, salt = randomBytes(16).toString('hex')) {
  const hash = scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, stored) {
  const [salt, expectedHex] = String(stored).split(':');
  if (!salt || !expectedHex) return false;
  const actual = scryptSync(password, salt, 64);
  const expected = Buffer.from(expectedHex, 'hex');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

function encode(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

export function createCoffeeService(options = {}) {
  const file = options.file ? path.resolve(options.file) : path.resolve('data/runtime.json');
  const publicFile = options.publicFile ? path.resolve(options.publicFile) : path.resolve('data/public-content.json');
  const mediaDir = options.mediaDir ? path.resolve(options.mediaDir) : path.resolve('data/media');
  const secret = options.secret || process.env.SESSION_SECRET || '';
  if (secret.length < 24) throw new Error('SESSION_SECRET must contain at least 24 characters');

  function load() {
    if (!fs.existsSync(file)) return clone(EMPTY_STATE);
    const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
    return {
      users: Array.isArray(parsed.users) ? parsed.users : [],
      records: Array.isArray(parsed.records) ? parsed.records : [],
      profiles: Array.isArray(parsed.profiles) ? parsed.profiles : [],
    };
  }

  function save(state) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const temp = `${file}.tmp`;
    fs.writeFileSync(temp, `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
    fs.renameSync(temp, file);
  }

  function sign(payload) {
    const body = encode(payload);
    const signature = createHmac('sha256', secret).update(body).digest('base64url');
    return `${body}.${signature}`;
  }

  function authenticate(token, tenantId) {
    const [body, signature] = String(token ?? '').split('.');
    if (!body || !signature) return null;
    const expected = createHmac('sha256', secret).update(body).digest('base64url');
    const actualBuffer = Buffer.from(signature);
    const expectedBuffer = Buffer.from(expected);
    if (actualBuffer.length !== expectedBuffer.length || !timingSafeEqual(actualBuffer, expectedBuffer)) return null;
    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (payload.exp <= Date.now() || payload.tenantId !== tenantId) return null;
    const state = load();
    const activeUser = state.users.find((user) => user.id === payload.userId && user.tenantId === tenantId && user.status !== 'closed');
    if (!activeUser) return null;
    return payload;
  }

  function register(input, tenantId) {
    const username = normalizeText(input.username, 80).toLowerCase();
    const password = String(input.password ?? '');
    const realName = normalizeText(input.realName, 60);
    const phone = normalizeText(input.phone, 20);
    if (username.length < 3 || password.length < 8 || !realName || !/^1\d{10}$/.test(phone)) {
      return { ok: false, message: '注册信息不完整或密码少于 8 位' };
    }
    if (!input.agreementVersion || !input.privacyVersion || !input.consentAcceptedAt) {
      return { ok: false, message: '必须主动同意用户协议与隐私政策' };
    }
    const state = load();
    if (state.users.some((user) => user.tenantId === tenantId && user.username === username)) {
      return { ok: false, message: '账号已存在' };
    }
    const user = {
      id: randomUUID(),
      tenantId,
      username,
      passwordHash: hashPassword(password),
      realName,
      phone,
      status: 'active',
      createdAt: new Date().toISOString(),
      consent: {
        agreementVersion: normalizeText(input.agreementVersion, 40),
        privacyVersion: normalizeText(input.privacyVersion, 40),
        acceptedAt: normalizeText(input.consentAcceptedAt, 48),
      },
    };
    state.users.push(user);
    state.profiles.push({ tenantId, userId: user.id, nickname: realName, bio: '', interestDirections: [], updatedAt: user.createdAt });
    save(state);
    return { ok: true, ...issueSession(user) };
  }

  function issueSession(user) {
    const payload = { userId: user.id, tenantId: user.tenantId, username: user.username, exp: Date.now() + 7 * 24 * 60 * 60 * 1000 };
    return { accessToken: sign(payload), user: { id: user.id, username: user.username } };
  }

  function login(input, tenantId) {
    const username = normalizeText(input.username, 80).toLowerCase();
    const state = load();
    const user = state.users.find((candidate) => candidate.tenantId === tenantId && candidate.username === username);
    if (!user || user.status === 'closed' || !verifyPassword(String(input.password ?? ''), user.passwordHash)) return { ok: false, message: '账号或密码错误' };
    return { ok: true, ...issueSession(user) };
  }

  function createRecord(session, kind, input) {
    const allowed = new Set(['brew', 'recipe', 'evaluation', 'favorite', 'learning', 'checkin']);
    if (!allowed.has(kind)) return { ok: false, message: '不支持的记录类型' };
    const state = load();
    const now = new Date().toISOString();
    if (kind === 'learning' || kind === 'favorite') {
      const key = kind === 'learning' ? normalizeText(input?.knowledgeId, 80) : `${normalizeText(input?.targetType, 40)}:${normalizeText(input?.targetId, 80)}`;
      if (!key || key === ':') return { ok: false, message: '记录目标不能为空' };
      const existing = state.records.find((candidate) => {
        if (candidate.tenantId !== session.tenantId || candidate.userId !== session.userId || candidate.kind !== kind || candidate.status !== 'active') return false;
        const candidateKey = kind === 'learning' ? normalizeText(candidate.payload?.knowledgeId, 80) : `${normalizeText(candidate.payload?.targetType, 40)}:${normalizeText(candidate.payload?.targetId, 80)}`;
        return candidateKey === key;
      });
      if (existing) return { ok: true, record: clone(existing), unchanged: true };
    }
    if (kind === 'checkin') {
      const day = now.slice(0, 10);
      const existing = state.records.find((candidate) => candidate.tenantId === session.tenantId && candidate.userId === session.userId && candidate.kind === 'checkin' && candidate.status === 'active' && candidate.createdAt.slice(0, 10) === day);
      if (existing) return { ok: true, record: clone(existing), unchanged: true };
    }
    const record = {
      id: randomUUID(),
      tenantId: session.tenantId,
      userId: session.userId,
      kind,
      status: 'active',
      version: 1,
      payload: clone(input ?? {}),
      createdAt: now,
      updatedAt: now,
    };
    state.records.push(record);
    save(state);
    return { ok: true, record: clone(record) };
  }

  function listRecords(session, kind) {
    const state = load();
    return state.records
      .filter((record) => record.tenantId === session.tenantId && record.userId === session.userId && (!kind || record.kind === kind))
      .map(clone);
  }

  function archiveRecord(session, id) {
    const state = load();
    const record = state.records.find((candidate) => candidate.id === id && candidate.tenantId === session.tenantId && candidate.userId === session.userId);
    if (!record) return { ok: false, message: '记录不存在或无权访问' };
    record.status = 'archived';
    record.version += 1;
    record.updatedAt = new Date().toISOString();
    save(state);
    return { ok: true, record: clone(record) };
  }

  function versionRecord(session, id, input) {
    const state = load();
    const previous = state.records.find((candidate) => candidate.id === id && candidate.tenantId === session.tenantId && candidate.userId === session.userId);
    if (!previous) return { ok: false, message: '记录不存在或无权访问' };
    const now = new Date().toISOString();
    previous.status = 'superseded';
    previous.updatedAt = now;
    const next = {
      ...previous,
      id: randomUUID(),
      status: 'active',
      version: previous.version + 1,
      parentVersionId: previous.id,
      payload: { ...clone(previous.payload), ...clone(input ?? {}) },
      createdAt: now,
      updatedAt: now,
    };
    state.records.push(next);
    save(state);
    return { ok: true, record: clone(next) };
  }

  function getProfile(session) {
    const state = load();
    const profile = state.profiles.find((item) => item.tenantId === session.tenantId && item.userId === session.userId);
    return clone(profile ?? { tenantId: session.tenantId, userId: session.userId, nickname: '', bio: '', interestDirections: [] });
  }

  function updateProfile(session, input) {
    const state = load();
    let profile = state.profiles.find((item) => item.tenantId === session.tenantId && item.userId === session.userId);
    if (!profile) {
      profile = { tenantId: session.tenantId, userId: session.userId, nickname: '', bio: '', interestDirections: [], updatedAt: '' };
      state.profiles.push(profile);
    }
    profile.nickname = normalizeText(input.nickname, 60);
    profile.bio = normalizeText(input.bio, 240);
    profile.interestDirections = Array.isArray(input.interestDirections) ? input.interestDirections.map((item) => normalizeText(item, 40)).filter(Boolean).slice(0, 12) : [];
    profile.updatedAt = new Date().toISOString();
    save(state);
    return { ok: true, profile: clone(profile) };
  }

  function publicItems(resource, id = '') {
    if (!fs.existsSync(publicFile)) return id ? null : [];
    const catalog = JSON.parse(fs.readFileSync(publicFile, 'utf8'));
    const items = Array.isArray(catalog[resource]) ? catalog[resource] : [];
    return id ? clone(items.find((item) => item.id === id) ?? null) : clone(items);
  }

  function evaluationStats(session) {
    const rows = listRecords(session, 'evaluation').filter((item) => item.status === 'active');
    if (rows.length === 0) return { count: 0, averages: {}, tags: [] };
    const dimensions = ['acidity', 'sweetness', 'bitterness', 'body', 'aroma', 'aftertaste', 'overall'];
    const averages = {};
    for (const key of dimensions) {
      const values = rows.map((item) => Number(item.payload?.scores?.[key] ?? 0)).filter((value) => value >= 1 && value <= 5);
      averages[key] = values.length ? Number((values.reduce((sum, value) => sum + value, 0) / values.length).toFixed(2)) : 0;
    }
    const tagCounts = new Map();
    for (const row of rows) for (const tag of Array.isArray(row.payload?.tags) ? row.payload.tags : []) tagCounts.set(tag, (tagCounts.get(tag) ?? 0) + 1);
    const tags = [...tagCounts.entries()].map(([name, count]) => ({ name, count })).sort((a, b) => b.count - a.count);
    return { count: rows.length, averages, tags };
  }

  function achievements(session) {
    const stats = growth(session);
    return [
      { id: 'first-learning', name: '初次学习', achieved: stats.learningCount >= 1 },
      { id: 'first-brew', name: '首次制作', achieved: stats.brewCount >= 1 },
      { id: 'first-evaluation', name: '首次测评', achieved: stats.evaluationCount >= 1 },
      { id: 'recipe-collector', name: '配方收藏', achieved: stats.recipeFavoriteCount >= 1 },
    ];
  }

  function saveImage(session, input) {
    const mimeType = normalizeText(input.mimeType, 40);
    const data = String(input.dataBase64 ?? '');
    if (!['image/jpeg', 'image/png'].includes(mimeType)) return { ok: false, message: '仅支持 JPEG 或 PNG' };
    let bytes;
    try { bytes = Buffer.from(data, 'base64'); } catch { return { ok: false, message: '图片数据无效' }; }
    if (bytes.length === 0 || bytes.length > 5 * 1024 * 1024) return { ok: false, message: '图片大小必须在 1B 至 5MB 之间' };
    const isPng = bytes.length > 7 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 && bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a;
    const isJpeg = bytes.length > 2 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
    if ((mimeType === 'image/png' && !isPng) || (mimeType === 'image/jpeg' && !isJpeg)) return { ok: false, message: '图片内容与格式不一致' };
    const extension = mimeType === 'image/png' ? 'png' : 'jpg';
    const ownerDir = path.join(mediaDir, session.tenantId, session.userId);
    fs.mkdirSync(ownerDir, { recursive: true });
    const key = `${randomUUID()}.${extension}`;
    fs.writeFileSync(path.join(ownerDir, key), bytes, { mode: 0o600 });
    return { ok: true, key, sizeBytes: bytes.length };
  }

  function readImage(session, key) {
    const safeKey = normalizeText(key, 80);
    if (!/^[0-9a-f-]+\.(png|jpg)$/.test(safeKey)) return null;
    const file = path.join(mediaDir, session.tenantId, session.userId, safeKey);
    if (!fs.existsSync(file)) return null;
    return { bytes: fs.readFileSync(file), mimeType: safeKey.endsWith('.png') ? 'image/png' : 'image/jpeg' };
  }

  function growth(session) {
    const records = listRecords(session);
    const counts = { learning: 0, brew: 0, recipe: 0, evaluation: 0, favorite: 0, checkin: 0 };
    let recipeFavoriteCount = 0;
    for (const record of records.filter((item) => item.status === 'active')) {
      if (Object.hasOwn(counts, record.kind)) counts[record.kind] += 1;
      if (record.kind === 'favorite' && record.payload?.targetType === 'recipe') recipeFavoriteCount += 1;
    }
    const experience = counts.learning * 5 + counts.brew * 12 + counts.recipe * 8 + counts.evaluation * 15 + counts.checkin * 3;
    return {
      learningCount: counts.learning,
      brewCount: counts.brew,
      recipeCount: counts.recipe,
      evaluationCount: counts.evaluation,
      favoriteCount: counts.favorite,
      recipeFavoriteCount,
      checkInCount: counts.checkin,
      experience,
    };
  }

  function activityStats(session) {
    const records = listRecords(session).filter((item) => item.status === 'active');
    const days = [];
    const dayMap = new Map();
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    for (let offset = 6; offset >= 0; offset -= 1) {
      const date = new Date(today);
      date.setUTCDate(today.getUTCDate() - offset);
      const key = date.toISOString().slice(0, 10);
      const item = { date: key, label: `${date.getUTCMonth() + 1}/${date.getUTCDate()}`, brewCount: 0, learningCount: 0, evaluationCount: 0 };
      days.push(item);
      dayMap.set(key, item);
    }
    const methods = new Map();
    for (const record of records) {
      const key = String(record.createdAt ?? '').slice(0, 10);
      const day = dayMap.get(key);
      if (day && record.kind === 'brew') day.brewCount += 1;
      if (day && record.kind === 'learning') day.learningCount += 1;
      if (day && record.kind === 'evaluation') day.evaluationCount += 1;
      if (record.kind === 'brew') {
        const method = normalizeText(record.payload?.method, 40) || '未填写';
        methods.set(method, (methods.get(method) ?? 0) + 1);
      }
    }
    return {
      days,
      methods: [...methods.entries()].map(([name, count]) => ({ name, count })).sort((a, b) => b.count - a.count),
    };
  }

  function closeAccount(session) {
    const state = load();
    const user = state.users.find((candidate) => candidate.id === session.userId && candidate.tenantId === session.tenantId && candidate.status !== 'closed');
    if (!user) return { ok: false, message: '账号不存在或已注销' };
    const now = new Date().toISOString();
    user.username = `closed-${user.id}@invalid.local`;
    user.passwordHash = hashPassword(randomBytes(32).toString('hex'));
    user.realName = '';
    user.phone = '';
    user.status = 'closed';
    user.closedAt = now;
    const profile = state.profiles.find((item) => item.tenantId === session.tenantId && item.userId === session.userId);
    if (profile) {
      profile.nickname = '';
      profile.bio = '';
      profile.interestDirections = [];
      profile.updatedAt = now;
      profile.archivedAt = now;
    }
    for (const record of state.records) {
      if (record.tenantId === session.tenantId && record.userId === session.userId && record.status !== 'archived') {
        record.status = 'archived';
        record.version += 1;
        record.updatedAt = now;
      }
    }
    save(state);
    return { ok: true, closedAt: now };
  }

  return { register, login, authenticate, createRecord, listRecords, archiveRecord, versionRecord, getProfile, updateProfile, publicItems, evaluationStats, achievements, saveImage, readImage, growth, activityStats, closeAccount, load };
}

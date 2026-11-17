import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const appRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const etsRoot = join(appRoot, 'entry', 'src', 'main', 'ets');
const pagesRoot = join(etsRoot, 'pages');
const pagesProfile = join(appRoot, 'entry', 'src', 'main', 'resources', 'base', 'profile', 'main_pages.json');
const registered = JSON.parse(readFileSync(pagesProfile, 'utf8')).src;
const pageFiles = readdirSync(pagesRoot).filter((name) => name.endsWith('.ets'));

function allSource() {
  return pageFiles.map((name) => readFileSync(join(pagesRoot, name), 'utf8')).join('\n');
}

test('every registered route has one entry page source', () => {
  assert.equal(new Set(registered).size, registered.length, 'main_pages.json contains duplicate routes');
  for (const route of registered) {
    const sourcePath = join(appRoot, 'entry', 'src', 'main', 'ets', `${route}.ets`);
    assert.ok(existsSync(sourcePath), `missing route source: ${route}`);
    assert.match(readFileSync(sourcePath, 'utf8'), /@Entry\s+@Component/, `${route} is not an entry component`);
  }
});

test('every literal AppRouter page target is registered', () => {
  const source = allSource();
  const targets = [...source.matchAll(/url:\s*'((?:pages\/)[A-Za-z0-9]+)'/g)].map((match) => match[1]);
  assert.ok(targets.length > 0, 'no literal routes discovered');
  for (const target of new Set(targets)) {
    assert.ok(registered.includes(target), `route target is absent from main_pages.json: ${target}`);
  }
});

test('five main tabs are stable and point to distinct business pages', () => {
  const source = readFileSync(join(pagesRoot, 'MainTabPage.ets'), 'utf8');
  for (const tab of [
    "new CoffeeTab(0, 'home', '首页')",
    "new CoffeeTab(1, 'study', '研习')",
    "new CoffeeTab(2, 'lab', '实验室')",
    "new CoffeeTab(3, 'recipe', '配方')",
    "new CoffeeTab(4, 'user', '我的')"
  ]) assert.ok(source.includes(tab), `missing tab: ${tab}`);
  for (const page of ['HomePage', 'StudyPage', 'LabPage', 'RecipePage', 'MinePage']) {
    assert.match(source, new RegExp(`${page}\\(`), `tab does not render ${page}`);
  }
});

test('knowledge, recipe and equipment favorites share visible persisted state', () => {
  const action = readFileSync(join(etsRoot, 'components', 'design-system', 'FavoriteAction.ets'), 'utf8');
  assert.match(action, /收藏中…/);
  assert.match(action, /已收藏/);
  assert.match(action, /favorite/);
  const api = readFileSync(join(etsRoot, 'services', 'CoffeeApi.ets'), 'utf8');
  assert.match(api, /static async hasFavorite/);
  for (const page of ['KnowledgeDetailPage.ets', 'RecipeDetailPage.ets', 'EquipmentDetailPage.ets']) {
    const source = readFileSync(join(pagesRoot, page), 'utf8');
    assert.match(source, /FavoriteAction\(/, `${page} does not use FavoriteAction`);
    assert.match(source, /loadFavoriteState\(\)/, `${page} does not restore favorite state`);
    assert.match(source, /favoriteSaving|saving/, `${page} has no duplicate-click guard`);
  }
});

test('private write forms expose validation and loading feedback', () => {
  const expectations = {
    'BrewRecordEditPage.ets': ['请填写咖啡名称', '正在保存并同步…'],
    'RecipeEditPage.ets': ['请填写配方名称', '请填写可执行的制作步骤', '正在保存…'],
    'FlavorEvaluationPage.ets': ['请填写咖啡豆', '正在保存并同步…'],
    'ProfilePage.ets': ['正在同步…', '个人资料已保存并同步']
  };
  for (const [page, messages] of Object.entries(expectations)) {
    const source = readFileSync(join(pagesRoot, page), 'utf8');
    for (const message of messages) assert.ok(source.includes(message), `${page} lacks feedback: ${message}`);
  }
});

test('login and registration always require a fresh explicit legal consent', () => {
  const source = readFileSync(join(pagesRoot, 'LoginPage.ets'), 'utf8');
  assert.match(source, /@State agreeLegal: boolean = false/);
  assert.doesNotMatch(source, /agreeLegal\s*=\s*PrivacyService\.isAccepted\(\)/);
  assert.match(source, /if \(!this\.agreeLegal\)/);
  assert.ok((source.match(/this\.agreeLegal = false/g) ?? []).length >= 2,
    'consent must reset on page entry and login/register mode switch');
});

test('home statistics refresh after every successful private write and never disguise load failures as zeros', () => {
  const api = readFileSync(join(etsRoot, 'services', 'CoffeeApi.ets'), 'utf8');
  const sync = readFileSync(join(etsRoot, 'services', 'CoffeeSync.ets'), 'utf8');
  const tabs = readFileSync(join(pagesRoot, 'MainTabPage.ets'), 'utf8');
  const home = readFileSync(join(pagesRoot, 'HomePage.ets'), 'utf8');
  assert.match(api, /if \(result\.code === 0\) CoffeeSync\.bump\(\)/,
    'successful private writes must publish one shared data revision');
  assert.match(sync, /coffeeDataRevision/);
  assert.match(tabs, /@StorageLink\('coffeeDataRevision'\) revision/,
    'the persistent tab shell must observe data revisions even while home is covered by a detail route');
  assert.match(tabs, /refreshToken: this\.revision \+ this\.homeVisitToken/,
    'home must receive both mutation and revisit refresh signals');
  assert.match(home, /@Prop @Watch\('onRefreshToken'\) refreshToken/);
  assert.match(home, /正在同步最新咖啡档案/);
  assert.match(home, /summaryError/);
  assert.match(home, /if \(result\.code === 0\) this\.loadSummary\(\)/,
    'home check-in must refresh immediately in addition to the shared revision signal');
});

test('async metric and achievement values use reactive components instead of captured builder arguments', () => {
  const metric = readFileSync(join(etsRoot, 'components', 'design-system', 'CoffeeMetricCard.ets'), 'utf8');
  assert.match(metric, /@Prop value: number/);
  assert.match(metric, /Text\(`\$\{this\.value\}`\)/);
  for (const page of ['HomePage.ets', 'LabPage.ets', 'GrowthPage.ets']) {
    const source = readFileSync(join(pagesRoot, page), 'utf8');
    assert.match(source, /CoffeeMetricCard\(/, `${page} does not render reactive metric cards`);
    assert.doesNotMatch(source, /this\.Stat\(/, `${page} still captures async values in a local builder`);
  }
  const growth = readFileSync(join(pagesRoot, 'GrowthPage.ets'), 'utf8');
  assert.match(growth, /struct GrowthAchievementRow/);
  assert.match(growth, /@Prop achieved: boolean/);
  assert.doesNotMatch(growth, /this\.Achievement\(/);
  assert.match(growth, /正在同步成长统计/);
});

test('all seven flavor sliders use two-way state links so displayed scores follow the thumb', () => {
  const control = readFileSync(join(etsRoot, 'components', 'design-system', 'FlavorScoreSlider.ets'), 'utf8');
  const page = readFileSync(join(pagesRoot, 'FlavorEvaluationPage.ets'), 'utf8');
  assert.match(control, /@Link value: number/);
  assert.match(control, /Text\(`\$\{this\.value\}\/5`\)/);
  assert.match(control, /this\.value = Math\.round\(score\)/);
  for (const state of ['acidity', 'sweetness', 'bitterness', 'body', 'aroma', 'aftertaste', 'overall']) {
    assert.match(page, new RegExp(`value: \\$${state}\\b`), `${state} is not two-way bound`);
  }
  assert.equal((page.match(/FlavorScoreSlider\(/g) ?? []).length, 7);
  assert.doesNotMatch(page, /this\.Score\(/);
});

test('login, registration and logout update the current page without a tab switch', () => {
  const session = readFileSync(join(etsRoot, 'services', 'SessionStore.ets'), 'utf8');
  const tabs = readFileSync(join(pagesRoot, 'MainTabPage.ets'), 'utf8');
  assert.match(session, /AppStorage\.setOrCreate\(KEY_TOKEN, token\)/);
  assert.match(session, /AppStorage\.setOrCreate\(KEY_TOKEN, ''\)/);
  assert.match(tabs, /private async logout\(\): Promise<void>/);
  assert.match(tabs, /await AuthService\.logout\(\)\s+this\.onLogout\(\)/,
    'the root refresh must happen only after persistent session clearing completes');
  for (const page of ['HomePage.ets', 'LabPage.ets', 'RecipePage.ets', 'MinePage.ets']) {
    const source = readFileSync(join(pagesRoot, page), 'utf8');
    assert.match(source, /@StorageLink\('accessToken'\) @Watch\('onSessionChanged'\) accessToken/,
      `${page} does not react to the session token`);
    assert.match(source, /this\.accessToken\.length/,
      `${page} still lacks a reactive authentication branch`);
  }
});

test('equipment comparison switches real catalog items and preserves the detail selection', () => {
  const detail = readFileSync(join(pagesRoot, 'EquipmentDetailPage.ets'), 'utf8');
  const compare = readFileSync(join(pagesRoot, 'EquipmentComparePage.ets'), 'utf8');
  assert.match(detail, /params: \{ id: this\.item\.id \}/,
    'equipment detail must pass the currently viewed item into comparison');
  assert.match(compare, /@State leftId: string/);
  assert.match(compare, /@State rightId: string/);
  assert.match(compare, /EquipmentSelector\(/);
  assert.match(compare, /onSelect: \(id: string\) => this\.selectLeft\(id\)/);
  assert.match(compare, /onSelect: \(id: string\) => this\.selectRight\(id\)/);
  assert.doesNotMatch(compare, /this\.Head\('V60'\)/,
    'comparison must not remain a fixed V60/flat-bed mock');
});

test('profile inputs are two-way linked and saving is confirmed by a server read-back', () => {
  const source = readFileSync(join(pagesRoot, 'ProfilePage.ets'), 'utf8');
  assert.match(source, /@Link value: string/);
  for (const field of ['nickname', 'bio', 'interest']) {
    assert.match(source, new RegExp(`value: \\$${field}\\b`), `${field} is not two-way bound`);
  }
  assert.match(source, /const confirmed = await CoffeeApi\.profile\(\)/);
  assert.match(source, /个人资料已保存并同步/);
  assert.match(source, /请填写昵称/);
});

test('user-facing pages do not expose development or test-version labels', () => {
  const tabs = readFileSync(join(pagesRoot, 'MainTabPage.ets'), 'utf8');
  const settings = readFileSync(join(pagesRoot, 'SettingsPage.ets'), 'utf8');
  const privacy = readFileSync(join(pagesRoot, 'PrivacyPolicyPage.ets'), 'utf8');
  const agreement = readFileSync(join(pagesRoot, 'UserAgreementPage.ets'), 'utf8');
  for (const source of [tabs, settings, privacy, agreement]) {
    assert.doesNotMatch(source, /开发期|测试版本|测试版|仅供测试|不代表正式发布/);
  }
});

test('legal operator is confirmed and consistent across user-facing legal surfaces', () => {
  const operator = '黑龙江省云富信息科技有限公司';
  const legalDocs = readFileSync(join(etsRoot, 'models', 'LegalDocs.ets'), 'utf8');
  const settings = readFileSync(join(pagesRoot, 'SettingsPage.ets'), 'utf8');
  const privacy = readFileSync(join(pagesRoot, 'PrivacyPolicyPage.ets'), 'utf8');
  const agreement = readFileSync(join(pagesRoot, 'UserAgreementPage.ets'), 'utf8');
  for (const source of [legalDocs, settings, privacy, agreement]) {
    assert.ok(source.includes(operator), 'confirmed legal operator is missing');
    assert.doesNotMatch(source, /运营者：待确认|开发者账号名称待确认/);
  }
});

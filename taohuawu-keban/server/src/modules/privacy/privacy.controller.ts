import { APP } from '../../../src/repository.mjs';
import { check, resolveIdentity } from '../../../src/security.mjs';

export interface AppIdentity { id: string; tenantId: string; username: string; displayName?: string }
export interface PlatformAuth {
  resolveAppSession(token: string): AppIdentity | null;
  findAppUserIdByUsername(tenantId: string, username: string): string | null;
  removeAppUser(tenantId: string, id: string): boolean;
}
export interface UserActivity { purgeUser(tenantId: string, userId: string): unknown }
interface AccountContext {
  auth: PlatformAuth;
  activity?: UserActivity;
  business: { purgeAccount(identity: AppIdentity): Promise<unknown> };
}

/** The platform's real DELETE /privacy/account delegates only this tenant here. */
export async function deleteCurrentAccount(context: AccountContext, headers: Record<string, string>, body: Record<string, unknown>) {
  check(body && typeof body === 'object' && !Array.isArray(body) && Object.keys(body).length === 0, 403, '注销仅使用当前认证身份');
  const identity = resolveIdentity(headers, context.auth);
  check(identity && context.auth.findAppUserIdByUsername(APP, identity.username) === identity.id, 401, '登录已失效，请重新登录');
  await context.business.purgeAccount(identity);
  // The explicit file-development harness has no activity collection; production supplies the real service.
  if (context.activity) await context.activity.purgeUser(APP, identity.id);
  check(context.auth.removeAppUser(APP, identity.id), 500, '注销未完成，请重试');
  return { deleted: true };
}

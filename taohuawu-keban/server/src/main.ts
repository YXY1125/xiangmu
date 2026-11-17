import fs from 'node:fs/promises';
import path from 'node:path';
import { PostgresRepository } from '../src/repository.mjs';
import { ArtBusiness } from '../src/service.mjs';
import { createDispatcher } from '../src/http.mjs';
import { BusinessError } from '../src/security.mjs';
import { databaseConnection } from '../src/database-config.mjs';
import { deleteCurrentAccount, PlatformAuth, UserActivity } from './modules/privacy/privacy.controller.js';

interface ProductionOptions {
  appRoot: string;
  connectionString?: string;
  databaseConfigFile?: string;
  platformPackage: string;
  auth: PlatformAuth;
  activity: UserActivity;
  resolveAdmin(headers: Record<string, string>): unknown;
}

/** SaaS26-hosted entry: no duplicate account system or standalone public listener. */
export async function createProductionRuntime(options: ProductionOptions) {
  const seed = JSON.parse(await fs.readFile(path.join(options.appRoot, 'db/seeds/001_content.json'), 'utf8'));
  const contracts = JSON.parse(await fs.readFile(path.join(options.appRoot, 'server/contracts/entities.json'), 'utf8'));
  const connectionString = await databaseConnection({ connectionString: options.connectionString, configFile: options.databaseConfigFile });
  const repository = await PostgresRepository.connect(connectionString, seed, contracts, options.platformPackage);
  const business = new ArtBusiness(repository);
  const dispatch = createDispatcher({ business, auth: options.auth, resolveAdmin: options.resolveAdmin });
  async function envelope(operation: () => Promise<unknown>) {
    try { return { code: 0, message: 'ok', data: await operation() }; }
    catch (error) {
      if (error instanceof BusinessError) return { code: error.status * 100 + 1, message: error.message, data: null };
      return { code: 50001, message: '服务处理失败，请稍后重试', data: null };
    }
  }
  return {
    dispatch(input: Parameters<typeof dispatch>[0]) { return envelope(() => dispatch(input)); },
    deleteCurrentAccount(headers: Record<string, string>, body: Record<string, unknown>) {
      return envelope(() => deleteCurrentAccount({ auth: options.auth, activity: options.activity, business }, headers, body));
    },
    async close() { await repository.pool.end(); },
  };
}

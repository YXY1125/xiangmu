import { Injectable } from '@nestjs/common';

export type RegisterInput = {
  username: string;
  password: string;
  realName: string;
  phone: string;
  inviteCode?: string;
};

/**
 * 本目录仅保留 V5.0 交付结构，不提供第二套认证或离线 token。
 * 生产认证统一由 saas26 platform/server AuthModule 提供。
 */
@Injectable()
export class AuthService {
  async login(_username: string, _password: string): Promise<null> {
    return null;
  }

  async register(_input: RegisterInput): Promise<null> {
    return null;
  }
}

export class ApiResponse<T> {
  code: number = 50001
  message: string = ''
  data?: T
}

export class LoginRequest {
  username: string = ''
  password: string = ''
  tenantId: string = ''
  deviceModel: string = ''
  aaid: string = ''
  toJsonString(): string {
    return `{"username":${JSON.stringify(this.username)},"password":${JSON.stringify(this.password)},"tenantId":${JSON.stringify(this.tenantId)},"deviceModel":${JSON.stringify(this.deviceModel)},"aaid":${JSON.stringify(this.aaid)}}`
  }
}

export class RegisterRequest extends LoginRequest {
  realName: string = ''
  phone: string = ''
  inviteCode: string = ''
  toJsonString(): string {
    return `{"username":${JSON.stringify(this.username)},"password":${JSON.stringify(this.password)},"realName":${JSON.stringify(this.realName)},"phone":${JSON.stringify(this.phone)},"inviteCode":${JSON.stringify(this.inviteCode)},"tenantId":${JSON.stringify(this.tenantId)},"deviceModel":${JSON.stringify(this.deviceModel)},"aaid":${JSON.stringify(this.aaid)}}`
  }
}

export class AuthUser {
  id: string = ''
  username: string = ''
  tenantId: string = ''
}

export class LoginResponse {
  accessToken: string = ''
  user: AuthUser = new AuthUser()
}

export class ActivityOpenRequest {
  deviceModel: string = ''
  aaid: string = ''
  tenantId: string = ''
  toJsonString(): string {
    return `{"deviceModel":${JSON.stringify(this.deviceModel)},"aaid":${JSON.stringify(this.aaid)},"tenantId":${JSON.stringify(this.tenantId)}}`
  }
}

export class EmptyPayload {}

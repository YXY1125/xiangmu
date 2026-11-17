import { Controller, Delete, Post } from '@nestjs/common';

@Controller('privacy')
export class PrivacyController {
  @Post('delete-data')
  requestDataRights() { return { code: 0, message: 'request accepted', data: { accepted: true } }; }

  @Delete('account')
  requestAccountClosure() { return { code: 0, message: 'request accepted', data: { accepted: true } }; }
}

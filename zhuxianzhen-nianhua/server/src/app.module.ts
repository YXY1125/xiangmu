import { Module } from '@nestjs/common';
import { PrivacyController } from './modules/privacy/privacy.controller';
import { ZhuxianzhenController } from './modules/zhuxianzhen/zhuxianzhen.controller';

@Module({ controllers: [PrivacyController, ZhuxianzhenController] })
export class AppModule {}

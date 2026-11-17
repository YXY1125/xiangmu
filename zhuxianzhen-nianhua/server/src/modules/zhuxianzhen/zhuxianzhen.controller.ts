import { Body, Controller, Get, Param, Post, Put, Req } from '@nestjs/common';

interface UserRequest { user?: { id?: string; username?: string }; }
interface ArtworkBody { id?: string; title?: string; layers?: object[]; revision?: number; }

@Controller('biz/zhuxianzhen')
export class ZhuxianzhenController {
  @Get('home')
  home() { return { code: 0, message: 'ok', data: { characters: [], articles: [], exhibitions: [] } }; }

  @Get('catalog/:type')
  catalog(@Param('type') type: string) {
    return { code: 0, message: 'ok', data: { type, items: [], total: 0 } };
  }

  @Get('catalog/:type/:id')
  detail(@Param('type') type: string, @Param('id') id: string) {
    return { code: 0, message: 'ok', data: { type, id } };
  }

  @Get('me/artworks')
  artworks(@Req() req: UserRequest) {
    const ownerId = req.user?.id || req.user?.username || '';
    return ownerId ? { code: 0, message: 'ok', data: { items: [], total: 0 } } :
      { code: 40101, message: '请先登录', data: { items: [], total: 0 } };
  }

  @Post('me/artworks')
  createArtwork(@Body() body: ArtworkBody, @Req() req: UserRequest) {
    const ownerId = req.user?.id || req.user?.username || '';
    if (!ownerId) return { code: 40101, message: '请先登录', data: null };
    return { code: 0, message: 'ok', data: { ...body, ownerId, revision: 1 } };
  }

  @Put('me/artworks/:id')
  updateArtwork(@Param('id') id: string, @Body() body: ArtworkBody, @Req() req: UserRequest) {
    const ownerId = req.user?.id || req.user?.username || '';
    if (!ownerId) return { code: 40101, message: '请先登录', data: null };
    return { code: 0, message: 'ok', data: { ...body, id, ownerId, revision: Number(body.revision || 0) + 1 } };
  }

  @Post('me/records')
  saveRecord(@Body() body: object, @Req() req: UserRequest) {
    const ownerId = req.user?.id || req.user?.username || '';
    return ownerId ? { code: 0, message: 'ok', data: { ...body, ownerId } } :
      { code: 40101, message: '请先登录', data: null };
  }
}

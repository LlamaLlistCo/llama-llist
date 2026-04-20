import { request } from '../common/network/httpClient';
import { Tag } from '../models/Tag';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

interface CreateTagRequest {
  name: string;
}

@Entry
@Component
struct TagManage {
  @State tags: Tag[] = [];
  @State nameInput: string = '';
  @State isSubmitting: boolean = false;

  aboutToAppear() {
    this.fetchTags();
  }

  build() {
    Column() {
      // ── 顶部导航栏 ──
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor(['#705C53'])
          .onClick(() => router.back())

        Blank()

        Text('标签管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4A3933')

        Blank()

        // 占位，保持标题居中
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor(['#00000000'])
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 16 })

      // ── 新增标签输入区 ──
      Row({ space: 10 }) {
        TextInput({ placeholder: '输入新标签名称…', text: this.nameInput })
          .onChange((v: string) => this.nameInput = v)
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontColor('#4A3933')
          .placeholderColor('#D2C4B0')
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .padding({ left: 14, right: 14 })

        Button() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(20)
            .fontColor(['#FFFFFF'])
        }
        .width(44)
        .height(44)
        .borderRadius(12)
        .backgroundColor('#705C53')
        .enabled(!this.isSubmitting)
        .onClick(() => this.createTag())
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 16 })

      // ── 标签列表 ──
      if (this.tags.length === 0) {
        // 空状态
        Column({ space: 12 }) {
          Text('🏷️').fontSize(52)
          Text('还没有标签，快来创建第一个吧')
            .fontSize(14)
            .fontColor('#A89982')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        List({ space: 10 }) {
          ForEach(this.tags, (tag: Tag) => {
            ListItem() {
              Row() {
                // 左侧小色块 + 标签名
                Row({ space: 10 }) {
                  Circle({ width: 8, height: 8 })
                    .fill('#A89982')
                  Text(tag.name)
                    .fontSize(16)
                    .fontColor('#4A3933')
                    .fontWeight(FontWeight.Medium)
                }

                Blank()

                // 删除按钮
                Row({ space: 4 }) {
                  SymbolGlyph($r('sys.symbol.trash'))
                    .fontSize(16)
                    .fontColor(['#C0392B'])
                  Text('删除')
                    .fontSize(13)
                    .fontColor('#C0392B')
                }
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor('#FDECEC')
                .borderRadius(8)
                .onClick(() => this.deleteTag(tag.id))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .shadow({ radius: 8, color: '#084A3933', offsetY: 3 })
            }
          }, (tag: Tag) => tag.id.toString())
        }
        .layoutWeight(1)
        .padding({ left: 20, right: 20, bottom: 20 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F9F8F4')
  }

  async fetchTags() {
    try {
      const data = await request<Tag[]>('/tags/', 'GET');
      this.tags = data ?? [];
    } catch (e) {
      promptAction.showToast({ message: '加载标签失败' });
    }
  }

  async createTag() {
    const name = this.nameInput.trim();
    if (!name) {
      promptAction.showToast({ message: '🦙 标签名不能为空' });
      return;
    }
    this.isSubmitting = true;
    try {
      const payload: CreateTagRequest = { name };
      await request<Tag>('/tags/', 'POST', payload);
      this.nameInput = '';
      await this.fetchTags();
      promptAction.showToast({ message: '标签添加成功 ✓' });
    } catch (e) {
      promptAction.showToast({ message: '添加失败（该标签可能已存在）' });
    } finally {
      this.isSubmitting = false;
    }
  }

  // async deleteTag(id: number) {
  //   try {
  //     await request<object>(`/tags/${id}`, 'DELETE');
  //     await this.fetchTags();
  //     promptAction.showToast({ message: '已删除' });
  //   } catch (e) {
  //     promptAction.showToast({ message: '删除失败' });
  //   }
  // }
  async deleteTag(id: number) {
    try {
      // 1. 发起删除请求
      // 注意：现在的 request 成功时可能返回 null，这是正常的
      await request<object>(`/tags/${id}`, 'DELETE');

      // 2. 执行到这里说明请求成功（responseCode 2xx）
      // 立即更新本地数组，触发界面刷新
      this.tags = this.tags.filter(t => t.id !== id);

      promptAction.showToast({ message: '标签已移除 🗑️' });
    } catch (e) {
      // 只有真正的网络错误或 4xx/5xx 错误才会来到这里
      console.error('删除标签确实失败了:', JSON.stringify(e));
      promptAction.showToast({ message: '删除失败，请稍后重试' });

      // 失败了就重新拉取数据，确保 UI 与后端同步
      this.fetchTags();
    }
  }
}

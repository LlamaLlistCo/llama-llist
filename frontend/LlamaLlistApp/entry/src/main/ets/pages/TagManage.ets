import { request } from '../common/network/httpClient';
import { Tag } from '../models/Tag';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

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
    Column({ space: 12 }) {
      Row() {
        Button('返回').onClick(() => router.back())
        Blank()
        Text('标签管理').fontSize(20).fontWeight(FontWeight.Medium)
        Blank()
      }
      .width('100%')
      .padding(16)

      Row({ space: 8 }) {
        TextInput({ placeholder: '新标签名称', text: this.nameInput })
          .onChange((v: string) => this.nameInput = v)
          .layoutWeight(1)
        Button('添加')
          .enabled(!this.isSubmitting)
          .onClick(() => this.createTag())
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      List({ space: 10 }) {
        ForEach(this.tags, (tag: Tag) => {
          ListItem() {
            Row() {
              Text(tag.name).fontSize(16)
              Blank()
              Button('删除')
                .backgroundColor('#FDECEC')
                .fontColor('#D93025')
                .onClick(() => this.deleteTag(tag.id))
            }
            .padding(12)
            .backgroundColor('#F5F5F5')
            .borderRadius(12)
          }
        }, (tag: Tag) => tag.id.toString())
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF')
  }

  async fetchTags() {
    try {
      const data = await request<Tag[]>('/tags/', 'GET');
      this.tags = data;
    } catch (e) {
      promptAction.showToast({ message: '加载标签失败' });
      console.error('加载标签失败', JSON.stringify(e));
    }
  }

  async createTag() {
    const name = this.nameInput.trim();
    if (!name) {
      promptAction.showToast({ message: '标签名不能为空' });
      return;
    }
    this.isSubmitting = true;
    try {
      await request<Tag>('/tags/', 'POST', { name });
      this.nameInput = '';
      await this.fetchTags();
      promptAction.showToast({ message: '添加成功' });
    } catch (e) {
      promptAction.showToast({ message: '添加失败（可能已存在）' });
      console.error('添加标签失败', JSON.stringify(e));
    } finally {
      this.isSubmitting = false;
    }
  }

  async deleteTag(id: number) {
    try {
      await request<object>(`/tags/${id}`, 'DELETE');
      await this.fetchTags();
      promptAction.showToast({ message: '删除成功' });
    } catch (e) {
      promptAction.showToast({ message: '删除失败' });
      console.error('删除标签失败', JSON.stringify(e));
    }
  }
}

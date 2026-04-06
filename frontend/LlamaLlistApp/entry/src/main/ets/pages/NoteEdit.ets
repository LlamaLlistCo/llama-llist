import { request } from '../common/network/httpClient';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Tag } from '../models/Tag';

interface NoteCreateRequest {
  title: string;
  content: string;
  image_paths?: string;
  tag_id?: number | null;
}

interface NoteResponse {
  id: number;
  title: string;
  content: string;
  image_paths?: string;
  tag_id?: number | null;
  created_at: string;
  updated_at: string;
}

@Entry
@Component
struct NoteEdit {
  @State noteId: number | null = null;
  @State title: string = '';
  @State content: string = '';
  @State imagePathInput: string = '';
  @State imagePaths: string[] = [];
  @State tags: Tag[] = [];
  @State tagId: number | null = null;
  @State isSaving: boolean = false;

  aboutToAppear() {
    const params = router.getParams() as Record<string, unknown> | undefined;
    const idVal = params?.['id'];
    if (typeof idVal === 'number') {
      this.noteId = idVal;
    } else if (typeof idVal === 'string' && idVal.trim()) {
      const parsed = Number(idVal);
      if (!Number.isNaN(parsed)) this.noteId = parsed;
    }
    this.fetchTags();
    if (this.noteId !== null) {
      this.fetchNote(this.noteId);
    }
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Button('取消')
          .onClick(() => {
            router.back();
          })
        Blank()
        Text(this.noteId === null ? '新建笔记' : '编辑笔记')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
        Blank()
        Button('保存')
          .onClick(() => {
            this.saveNote();
          })
          .enabled(!this.isSaving)
      }
      .width('100%')
      .padding(16)

      // 输入区域
      Scroll() {
        Column({ space: 16 }) {
          TextInput({ placeholder: '标题（必填）', text: this.title })
            .onChange((value: string) => {
              this.title = value;
            })
            .maxLength(200)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)

          TextArea({ placeholder: '内容（可选）', text: this.content })
            .onChange((value: string) => {
              this.content = value;
            })
            .height(200)
            .fontSize(16)

          if (this.tags.length > 0) {
            Column({ space: 8 }) {
              Text('标签').fontSize(14).fontColor('#666')
              Row({ space: 8 }) {
                Button('无标签')
                  .backgroundColor(this.tagId === null ? '#333' : '#EEE')
                  .fontColor(this.tagId === null ? '#FFF' : '#333')
                  .onClick(() => {
                    this.tagId = null;
                  })
                ForEach(this.tags, (tag: Tag) => {
                  Button(tag.name)
                    .backgroundColor(this.tagId === tag.id ? '#333' : '#EEE')
                    .fontColor(this.tagId === tag.id ? '#FFF' : '#333')
                    .onClick(() => {
                      this.tagId = tag.id;
                    })
                }, (tag: Tag) => tag.id.toString())
              }.width('100%').flexWrap(FlexWrap.Wrap)
            }.width('100%')
          }

          Column({ space: 8 }) {
            Text('图片').fontSize(14).fontColor('#666')
            Row({ space: 8 }) {
              TextInput({ placeholder: '输入图片路径或 URL', text: this.imagePathInput })
                .onChange((value: string) => {
                  this.imagePathInput = value;
                })
                .layoutWeight(1)
              Button('添加')
                .onClick(() => {
                  const p = this.imagePathInput.trim();
                  if (!p) return;
                  if (this.imagePaths.indexOf(p) === -1) {
                    this.imagePaths = [...this.imagePaths, p];
                  }
                  this.imagePathInput = '';
                })
            }.width('100%')

            if (this.imagePaths.length > 0) {
              Column({ space: 8 }) {
                ForEach(this.imagePaths, (p: string, idx: number) => {
                  Row({ space: 8 }) {
                    Image(p).width(80).height(80).borderRadius(8).objectFit(ImageFit.Cover)
                    Text(p).fontSize(12).fontColor('#999').maxLines(2).layoutWeight(1)
                    Button('移除')
                      .onClick(() => {
                        this.imagePaths = this.imagePaths.filter((_, i) => i !== idx);
                      })
                  }
                  .padding(8)
                  .backgroundColor('#F5F5F5')
                  .borderRadius(12)
                }, (p: string) => p)
              }.width('100%')
            }
          }.width('100%')
        }
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF')
  }

  async saveNote() {
    console.info('saveNote 被调用');
    if (!this.title.trim()) {
      promptAction.showToast({ message: '标题不能为空' });
      return;
    }

    this.isSaving = true;
    try {
      const payload: NoteCreateRequest = {
        title: this.title.trim(),
        content: this.content || '',
        image_paths: this.imagePaths.length ? this.imagePaths.join(',') : undefined,
        tag_id: this.tagId
      };

      if (this.noteId === null) {
        await request<NoteResponse>('/notes/', 'POST', payload);
      } else {
        await request<NoteResponse>(`/notes/${this.noteId}`, 'PUT', payload);
      }
      promptAction.showToast({ message: '保存成功' });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: '保存失败，请检查网络' });
      console.error('保存失败', JSON.stringify(e));
    } finally {
      this.isSaving = false;
    }
  }

  async fetchTags() {
    try {
      const data = await request<Tag[]>('/tags/', 'GET');
      this.tags = data;
    } catch (e) {
      console.error('加载标签失败', JSON.stringify(e));
    }
  }

  async fetchNote(id: number) {
    try {
      const note = await request<NoteResponse>(`/notes/${id}`, 'GET');
      this.title = note.title || '';
      this.content = note.content || '';
      this.tagId = typeof note.tag_id === 'number' ? note.tag_id : null;
      const raw = (note.image_paths || '').trim();
      this.imagePaths = raw ? raw.split(',').map(s => s.trim()).filter(Boolean) : [];
    } catch (e) {
      promptAction.showToast({ message: '加载失败，返回列表' });
      console.error('加载笔记失败', JSON.stringify(e));
      router.back();
    }
  }
}

import { request } from '../common/network/httpClient';
import { Note } from '../models/Note';
import { Tag } from '../models/Tag';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct SearchPage {
  @State q: string = '';
  @State fromDateInput: string = '';
  @State toDateInput: string = '';
  @State tags: Tag[] = [];
  @State tagId: number | null = null;
  @State results: Note[] = [];
  @State isLoading: boolean = false;

  aboutToAppear() {
    this.fetchTags();
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button('返回').onClick(() => router.back())
        Blank()
        Text('搜索筛选').fontSize(20).fontWeight(FontWeight.Medium)
        Blank()
      }
      .width('100%')
      .padding(16)

      Column({ space: 10 }) {
        TextInput({ placeholder: '关键字（标题/内容）', text: this.q })
          .onChange((v: string) => this.q = v)
        TextInput({ placeholder: '开始日期（YYYY-MM-DD，可选）', text: this.fromDateInput })
          .onChange((v: string) => this.fromDateInput = v)
        TextInput({ placeholder: '结束日期（YYYY-MM-DD，可选）', text: this.toDateInput })
          .onChange((v: string) => this.toDateInput = v)

        if (this.tags.length > 0) {
          Column({ space: 8 }) {
            Text('标签').fontSize(14).fontColor('#666')
            Row({ space: 8 }) {
              Button('全部')
                .backgroundColor(this.tagId === null ? '#333' : '#EEE')
                .fontColor(this.tagId === null ? '#FFF' : '#333')
                .onClick(() => this.tagId = null)
              ForEach(this.tags, (tag: Tag) => {
                Button(tag.name)
                  .backgroundColor(this.tagId === tag.id ? '#333' : '#EEE')
                  .fontColor(this.tagId === tag.id ? '#FFF' : '#333')
                  .onClick(() => this.tagId = tag.id)
              }, (tag: Tag) => tag.id.toString())
            }.width('100%').flexWrap(FlexWrap.Wrap)
          }.width('100%')
        }

        Row({ space: 8 }) {
          Button('搜索')
            .enabled(!this.isLoading)
            .onClick(() => this.search())
          Button('清空')
            .onClick(() => {
              this.q = '';
              this.fromDateInput = '';
              this.toDateInput = '';
              this.tagId = null;
              this.results = [];
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      if (this.isLoading) {
        LoadingProgress().height(50).margin({ top: 30 });
      } else if (this.results.length === 0) {
        Column() {
          Text('暂无结果').fontSize(16).fontColor('#999')
        }.layoutWeight(1).justifyContent(FlexAlign.Center);
      } else {
        List({ space: 10 }) {
          ForEach(this.results, (note: Note) => {
            ListItem() {
              Column({ space: 6 }) {
                Text(note.title).fontSize(16).fontWeight(FontWeight.Medium).maxLines(1)
                Text(note.content || '无内容')
                  .fontSize(13)
                  .fontColor('#666')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(new Date(note.created_at).toLocaleString())
                  .fontSize(12)
                  .fontColor('#999')
              }
              .padding(12)
              .backgroundColor('#F5F5F5')
              .borderRadius(12)
            }
            .onClick(() => router.pushUrl({ url: 'pages/NoteEdit', params: { id: note.id } }))
          }, (note: Note) => note.id.toString())
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
      }
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
      console.error('加载标签失败', JSON.stringify(e));
    }
  }

  parseDateInput(value: string, endOfDay: boolean): string | null {
    const v = value.trim();
    if (!v) return null;
    const d = new Date(v);
    if (Number.isNaN(d.getTime())) return null;
    if (endOfDay) {
      d.setHours(23, 59, 59, 999);
    } else {
      d.setHours(0, 0, 0, 0);
    }
    return d.toISOString();
  }

  async search() {
    const fromIso = this.parseDateInput(this.fromDateInput, false);
    const toIso = this.parseDateInput(this.toDateInput, true);
    if (this.fromDateInput.trim() && !fromIso) {
      promptAction.showToast({ message: '开始日期格式不正确' });
      return;
    }
    if (this.toDateInput.trim() && !toIso) {
      promptAction.showToast({ message: '结束日期格式不正确' });
      return;
    }

    const params: string[] = [];
    const q = this.q.trim();
    if (q) params.push(`q=${encodeURIComponent(q)}`);
    if (fromIso) params.push(`created_from=${encodeURIComponent(fromIso)}`);
    if (toIso) params.push(`created_to=${encodeURIComponent(toIso)}`);
    if (this.tagId !== null) params.push(`tag_id=${this.tagId}`);
    const qs = params.length ? `?${params.join('&')}` : '';

    this.isLoading = true;
    try {
      const data = await request<Note[]>(`/notes/${qs}`, 'GET');
      this.results = data;
    } catch (e) {
      promptAction.showToast({ message: '搜索失败' });
      console.error('搜索失败', JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }
}

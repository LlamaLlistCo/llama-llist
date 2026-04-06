import { request } from '../common/network/httpClient';
import { Note } from '../models/Note';
import { Tag } from '../models/Tag';
import router from '@ohos.router';

@Entry
@Component
struct Index {
  @State notes: Note[] = [];
  @State tags: Tag[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.fetchTags();
    this.fetchNotes();
  }

  async fetchNotes() {
    try {
      this.isLoading = true;
      const data = await request<Note[]>('/notes/', 'GET');
      this.notes = data;
    } catch (e) {
      console.error('加载笔记失败', JSON.stringify(e));
    } finally {
      this.isLoading = false;
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

  tagNameById(tagId?: number): string {
    if (typeof tagId !== 'number') return '';
    const found = this.tags.find(t => t.id === tagId);
    return found ? found.name : '';
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('📝 灵感笔记')
          .fontSize(24)
          .fontWeight(FontWeight.Bold);
        Blank();
        Button('搜索')
          .onClick(() => {
            router.pushUrl({ url: 'pages/SearchPage' });
          })
        Button('标签')
          .onClick(() => {
            router.pushUrl({ url: 'pages/TagManage' });
          })
        Button('待办')
          .onClick(() => {
            router.pushUrl({ url: 'pages/TodoBoard' });
          })
        Button('新建')
          .onClick(() => {
            router.pushUrl({ url: 'pages/NoteEdit' });
          })
      }
      .width('100%')
      .padding(16);

      // 笔记列表
      if (this.isLoading) {
        LoadingProgress().height(50).margin({ top: 50 });
      } else if (this.notes.length === 0) {
        Column() {
          Text('暂无笔记，点击右上角新建')
            .fontSize(16)
            .fontColor('#999')
        }.layoutWeight(1).justifyContent(FlexAlign.Center);
      } else {
        List({ space: 12 }) {
          ForEach(this.notes, (note: Note) => {
            ListItem() {
              Column() {
                Text(note.title)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1);
                if (this.tagNameById(note.tag_id)) {
                  Text(this.tagNameById(note.tag_id))
                    .fontSize(12)
                    .fontColor('#333')
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .backgroundColor('#EEE')
                    .borderRadius(10)
                    .margin({ top: 6 })
                }
                Text(note.content || '无内容')
                  .fontSize(14)
                  .fontColor('#666')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
                Text(new Date(note.created_at).toLocaleString())
                  .fontSize(12)
                  .fontColor('#999')
                  .margin({ top: 8 });
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#F5F5F5')
              .borderRadius(12)
            }
            .onClick(() => {
              router.pushUrl({ url: 'pages/NoteEdit', params: { id: note.id } });
            });
          }, (note: Note) => note.id.toString())
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF')
  }
}

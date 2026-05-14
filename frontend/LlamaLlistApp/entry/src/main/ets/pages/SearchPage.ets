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
  @State hasSearched: boolean = false;
  @StorageLink('themeBg') themeBg: string = '#F9F8F4';

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

        Text('搜索笔记')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4A3933')

        Blank()

        // 清空按钮
        Text('清空')
          .fontSize(14)
          .fontColor(
            (this.q || this.fromDateInput || this.toDateInput || this.tagId !== null)
              ? '#A89982'
              : '#00000000'
          )
          .onClick(() => {
            this.q = '';
            this.fromDateInput = '';
            this.toDateInput = '';
            this.tagId = null;
            this.results = [];
            this.hasSearched = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 16 })

      Scroll() {
        Column({ space: 14 }) {
          // ── 关键字输入 ──
          Column({ space: 6 }) {
            Text('关键字')
              .fontSize(12)
              .fontColor('#A89982')
              .padding({ left: 4 })

            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(18)
                .fontColor(['#A89982'])

              TextInput({ placeholder: '搜索标题或内容…', text: this.q })
                .onChange((v: string) => this.q = v)
                .layoutWeight(1)
                .fontSize(15)
                .fontColor('#4A3933')
                .placeholderColor('#D2C4B0')
                .backgroundColor(Color.Transparent)
                .padding(0)
                .onSubmit(() => this.search())
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .shadow({ radius: 6, color: '#064A3933', offsetY: 2 })
          }
          .width('100%')

          // ── 日期范围 ──
          Column({ space: 6 }) {
            Text('日期范围')
              .fontSize(12)
              .fontColor('#A89982')
              .padding({ left: 4 })

            //   Row({ space: 10 }) {
            //     TextInput({ placeholder: '开始 YYYY-MM-DD', text: this.fromDateInput })
            //       .onChange((v: string) => this.fromDateInput = v)
            //       .layoutWeight(1)
            //       .fontSize(14)
            //       .fontColor('#4A3933')
            //       .placeholderColor('#D2C4B0')
            //       .backgroundColor('#FFFFFF')
            //       .borderRadius(12)
            //       .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            //
            //     Text('–').fontSize(14).fontColor('#D2C4B0')
            //
            //     TextInput({ placeholder: '结束 YYYY-MM-DD', text: this.toDateInput })
            //       .onChange((v: string) => this.toDateInput = v)
            //       .layoutWeight(1)
            //       .fontSize(14)
            //       .fontColor('#4A3933')
            //       .placeholderColor('#D2C4B0')
            //       .backgroundColor('#FFFFFF')
            //       .borderRadius(12)
            //       .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            //   }
            //   .width('100%')
            // }
            // .width('100%')
            // 修改日期选择部分的布局
            Row({ space: 10 }) {
              // 开始日期
              Row() {
                Text(this.fromDateInput || '开始日期')
                  .fontSize(14)
                  .fontColor(this.fromDateInput ? '#4A3933' : '#D2C4B0')
              }
              .layoutWeight(1)
              .height(40)
              .padding({ left: 12 })
              .backgroundColor('#F0EDE7')
              .borderRadius(8)
              .onClick(() => {
                DatePickerDialog.show({
                  start: new Date('2020-1-1'),
                  end: new Date(),
                  onAccept: (value: DatePickerResult) => {
                    const year = value.year ?? new Date().getFullYear();
                    const month = (value.month ?? new Date().getMonth()) + 1;
                    const day = value.day ?? new Date().getDate();
                    this.fromDateInput = `${year}-${month}-${day}`;
                  }
                })
              })

              Text('至').fontColor('#A89982')

              // 结束日期
              Row() {
                Text(this.toDateInput || '结束日期')
                  .fontSize(14)
                  .fontColor(this.toDateInput ? '#4A3933' : '#D2C4B0')
              }
              .layoutWeight(1)
              .height(40)
              .padding({ left: 12 })
              .backgroundColor('#F0EDE7')
              .borderRadius(8)
              .onClick(() => {
                DatePickerDialog.show({
                  start: new Date('2020-1-1'),
                  end: new Date(),
                  onAccept: (value: DatePickerResult) => {
                    const year = value.year ?? new Date().getFullYear();
                    const month = (value.month ?? new Date().getMonth()) + 1;
                    const day = value.day ?? new Date().getDate();
                    this.toDateInput = `${year}-${month}-${day}`;
                  }
                })
              })
            }
            .width('100%')
            .padding({ left: 20, right: 20, bottom: 10 })
          }

          // ── 标签筛选 ──
          if (this.tags.length > 0) {
            Column({ space: 8 }) {
              Text('标签筛选')
                .fontSize(12)
                .fontColor('#A89982')
                .padding({ left: 4 })

              Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                // 全部
                Text('全部')
                  .fontSize(13)
                  .fontColor(this.tagId === null ? '#FFF' : '#705C53')
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .backgroundColor(this.tagId === null ? '#705C53' : '#EFEBE9')
                  .borderRadius(20)
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => this.tagId = null)

                ForEach(this.tags, (tag: Tag) => {
                  Text(tag.name)
                    .fontSize(13)
                    .fontColor(this.tagId === tag.id ? '#FFF' : '#705C53')
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .backgroundColor(this.tagId === tag.id ? '#705C53' : '#EFEBE9')
                    .borderRadius(20)
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => this.tagId = tag.id)
                }, (tag: Tag) => tag.id.toString())
              }
              .width('100%')
            }
            .width('100%')
          }

          // ── 搜索按钮 ──
          Button() {
            Row({ space: 8 }) {
              if (this.isLoading) {
                LoadingProgress().width(18).height(18).color('#FFFFFF')
              } else {
                SymbolGlyph($r('sys.symbol.magnifyingglass'))
                  .fontSize(16)
                  .fontColor(['#FFFFFF'])
              }
              Text(this.isLoading ? '搜索中…' : '开始搜索')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
            }
          }
          .width('100%')
          .height(48)
          .backgroundColor('#705C53')
          .borderRadius(14)
          .enabled(!this.isLoading)
          .onClick(() => this.search())
        }
        .padding({ left: 20, right: 20, bottom: 20 })
      }
      .scrollBar(BarState.Off)
      // 搜索条件区域最多占一半屏幕高度，其余留给结果
      .constraintSize({ maxHeight: '50%' })

      // ── 分割线 ──
      if (this.hasSearched) {
        Divider().color('#EFEBE9').strokeWidth(1).padding({ left: 20, right: 20 })
      }

      // ── 搜索结果区 ──
      // ── 搜索结果区 ──
      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40).color('#A89982')
          Text('搜索中…').fontSize(14).fontColor('#A89982').margin({ top: 10 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')

      } else if (this.hasSearched && this.results.length === 0) {
        Column({ space: 12 }) {
          Text('🔍').fontSize(48)
          Text('没有找到匹配的笔记')
            .fontSize(14)
            .fontColor('#A89982')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')

      } else if (this.results.length > 0) {
        List({ space: 12 }) {
          ForEach(this.results, (note: Note) => {
            ListItem() {
              Column({ space: 8 }) {
                // 1. 标题
                Text(note.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#4A3933')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                // 2. 摘要（仅在存在时显示）
                if (note.summary && note.summary.trim() !== '') {
                  Text(note.summary)
                    .fontSize(13)
                    .fontColor('#887A73')
                    .maxLines(2)
                    .lineHeight(19)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }

                // 3. 底部信息栏（日期 + 标签）
                Row() {
                  Text(new Date(note.created_at).toLocaleDateString())
                    .fontSize(11)
                    .fontColor('#D2C4B0')

                  Blank()

                  // 如果笔记有标签，显示标签
                  if (this.getTagName(note.tag_id) !== '') {
                    Row() {
                      Circle({ width: 4, height: 4 }).fill('#705C53').margin({ right: 6 })
                      Text(this.getTagName(note.tag_id))
                        .fontSize(10)
                        .fontColor('#705C53')
                    }
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .backgroundColor('#EFEBE9')
                    .borderRadius(12)
                  }
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .shadow({ radius: 8, color: '#084A3933', offsetY: 3 })
            }
            .onClick(() => {
              router.pushUrl({
                url: 'pages/NoteEdit',
                params: { id: note.id }// 统一参数名为 noteId
              })
            })
          }, (note: Note) => note.id.toString())
        }
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 12, bottom: 20 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

      } else {
        // 未搜索时的引导状态
        Column({ space: 12 }) {
          Text('🦙').fontSize(48)
          Text('输入关键字或选择标签开始搜索')
            .fontSize(14)
            .fontColor('#A89982')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBg)
  }

  async fetchTags() {
    try {
      const data = await request<Tag[]>('/tags/', 'GET');
      this.tags = data ?? [];
    } catch (e) {
      console.error('加载标签失败', JSON.stringify(e));
    }
  }

  getTagName(tagId: number | null | undefined): string {
    if (tagId === null || tagId === undefined) return '';
    const tag = this.tags.find(t => t.id === tagId);
    return tag ? tag.name : '';
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

  // async search() {
  //   const fromIso = this.parseDateInput(this.fromDateInput, false);
  //   const toIso = this.parseDateInput(this.toDateInput, true);
  //   if (this.fromDateInput.trim() && !fromIso) {
  //     promptAction.showToast({ message: '开始日期格式不正确' });
  //     return;
  //   }
  //   if (this.toDateInput.trim() && !toIso) {
  //     promptAction.showToast({ message: '结束日期格式不正确' });
  //     return;
  //   }
  //
  //   const params: string[] = [];
  //   const q = this.q.trim();
  //   if (q) params.push(`q=${encodeURIComponent(q)}`);
  //   if (fromIso) params.push(`created_from=${encodeURIComponent(fromIso)}`);
  //   if (toIso) params.push(`created_to=${encodeURIComponent(toIso)}`);
  //   if (this.tagId !== null) params.push(`tag_id=${this.tagId}`);
  //   const qs = params.length ? `?${params.join('&')}` : '';
  //
  //   this.isLoading = true;
  //   this.hasSearched = true;
  //   try {
  //     const data = await request<Note[]>(`/notes/${qs}`, 'GET');
  //     this.results = data;
  //   } catch (e) {
  //     promptAction.showToast({ message: '搜索失败，请检查网络' });
  //   } finally {
  //     this.isLoading = false;
  //   }
  // }

  async search() {
    // 1. 解析日期
    const fromIso = this.parseDateInput(this.fromDateInput, false);
    const toIso = this.parseDateInput(this.toDateInput, true);

    // 2. 逻辑校验：如果两个日期都存在，检查顺序
    if (fromIso && toIso) {
      const fromDate = new Date(fromIso);
      const toDate = new Date(toIso);

      if (fromDate > toDate) {
        promptAction.showToast({ message: '🦙 开始日期不能晚于结束日期' });
        return;
      }
    }

    // 3. 原有的搜索逻辑
    this.isLoading = true;
    this.hasSearched = true;
    try {
      const params: string[] = [];
      const q = this.q.trim();
      if (q) params.push(`q=${encodeURIComponent(q)}`);
      if (fromIso) params.push(`created_from=${encodeURIComponent(fromIso)}`);
      if (toIso) params.push(`created_to=${encodeURIComponent(toIso)}`);
      if (this.tagId !== null) params.push(`tag_id=${this.tagId}`);

      const queryString = params.length ? '?' + params.join('&') : '';
      const data = await request<Note[]>(`/notes/${queryString}`, 'GET');
      this.results = data ?? [];
    } catch (e) {
      promptAction.showToast({ message: '搜索失败' });
      this.results = [];
    } finally {
      this.isLoading = false;
    }
  }
}

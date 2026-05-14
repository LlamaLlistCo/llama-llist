import { request as httpRequest } from '../common/network/httpClient';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Tag } from '../models/Tag';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { cameraPicker, camera } from '@kit.CameraKit';
import commonRequest from '@ohos.request';

interface NoteCreateRequest {
  title: string;
  summary?: string;
  view_type?: string;
  content: string;
  image_paths?: string;
  tag_id?: number | null;
}

interface NoteResponse {
  id: number;
  title: string;
  summary?: string;
  view_type: string;
  content: string;
  image_paths?: string;
  tag_id?: number | null;
  created_at: string;
  updated_at: string;
}

interface NoteTemplate {
  id: number;
  name: string;
  category: string;
  content_skeleton: string;
  icon?: string;
}

interface UploadResponse {
  url: string;
}

// AI 相关类型
interface AIExtractResult {
  keywords: string[];
  labels: string[];
  todos: string[];
  priority: string;
  summary: string;
}

interface AIExtractResponse {
  result: AIExtractResult;
}

interface AISummarizeResponse {
  summary: string;
  keywords?: string[];
}

interface TodoApplyPayload {
  todos: string[];
}

interface TodoApplyResponse {
  id: number;
}

// 对话框结果类型
interface DialogResult {
  index: number;
}

// ==================== 上传图片 ====================
@CustomDialog
struct ImageSourceDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });
  onSelect: (type: 'album' | 'camera' | 'url') => void = () => {};

  build(): void {
    Column() {
      Text('添加图片')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .padding(20);

      List() {
        ListItem() {
          this.OptionItem($r('sys.symbol.picture'), '从相册选择', (): void => this.handleSelect('album'));
        }
        ListItem() {
          this.OptionItem($r('sys.symbol.camera'), '拍照', (): void => this.handleSelect('camera'));
        }
        ListItem() {
          this.OptionItem($r('sys.symbol.link'), '上传图片 URL', (): void => this.handleSelect('url'));
        }
      }
      .divider({ strokeWidth: 1, color: '#EFEBE9' })
      .padding({ bottom: 10 });
    }
    .backgroundColor(Color.White)
    .borderRadius(20)
    .width('90%');
  }

  @Builder
  OptionItem(icon: Resource, label: string, action: () => void): void {
    Row({ space: 15 }) {
      SymbolGlyph(icon).fontSize(24).fontColor(['#705C53']);
      Text(label).fontSize(16).fontColor('#4A3933');
    }
    .width('100%')
    .padding(16)
    .onClick(action);
  }

  handleSelect(type: 'album' | 'camera' | 'url'): void {
    this.onSelect(type);
    this.controller.close();
  }
}

// ==================== 模板弹窗 ====================
@CustomDialog
struct TemplateDialog {
  @Prop templates: NoteTemplate[] = [];
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });
  onSelect: (skeleton: string) => void = () => {};

  build(): void {
    Column() {
      Row() {
        Text('选择笔记模板')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4A3933');
        Blank();
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(20)
          .fontColor(['#A89982'])
          .onClick(() => this.controller.close());
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 });

      Divider().color('#EFEBE9').strokeWidth(1);

      if (this.templates.length === 0) {
        Column({ space: 10 }) {
          Text('📋').fontSize(36);
          Text('暂无可用模板').fontSize(14).fontColor('#A89982');
        }
        .width('100%')
        .padding(40)
        .justifyContent(FlexAlign.Center);
      } else {
        List({ space: 10 }) {
          ForEach(this.templates, (item: NoteTemplate) => {
            ListItem() {
              Row({ space: 12 }) {
                Text(item.icon || '📝').fontSize(28);
                Column({ space: 4 }) {
                  Text(item.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#4A3933');
                  Text(item.category)
                    .fontSize(12)
                    .fontColor('#A89982');
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16)
                  .fontColor(['#D2C4B0']);
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#F9F8F4')
              .borderRadius(12)
              .onClick(() => {
                this.onSelect(item.content_skeleton);
                this.controller.close();
              });
            }
          });
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 16 })
        .constraintSize({ maxHeight: 400 })
        .width('100%')
        .scrollBar(BarState.Off);
      }
    }
    .backgroundColor(Color.White)
    .borderRadius(20);
  }
}

// ==================== 颜色选择弹窗 ====================
@CustomDialog
struct PickerDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });
  onSelect: (color: string) => void = () => {};

  private colors: string[] = [
    '#4A3933',
    '#C0392B',
    '#E67E22',
    '#D4AC0D',
    '#27AE60',
    '#2980B9',
    '#8E44AD',
    '#A89982',
  ];

  build(): void {
    Column({ space: 16 }) {
      Text('选择字体颜色')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3933')
        .padding({ top: 20, left: 20 })
        .width('100%');

      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(this.colors, (c: string) => {
          Column()
            .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor(c)
            .margin(8)
            .border({ width: 3, color: '#FFFFFF' })
            .shadow({ radius: 4, color: '#20000000', offsetY: 2 })
            .onClick(() => {
              this.onSelect(c);
              this.controller.close();
            });
        });
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 24 });
    }
    .backgroundColor(Color.White)
    .borderRadius(20);
  }
}

@CustomDialog
struct UrlInputDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });
  onConfirm: (url: string) => void = () => {};
  @State inputUrl: string = '';

  build(): void {
    Column({ space: 16 }) {
      Text('输入图片地址')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3933')
        .padding({ top: 20 });

      TextInput({
        text: this.inputUrl,
        placeholder: 'https://example.com/image.jpg'
      })
        .fontSize(14)
        .placeholderColor('#D2C4B0')
        .fontColor('#4A3933')
        .backgroundColor('#F9F8F4')
        .borderRadius(8)
        .padding(12)
        .width('100%')
        .onChange((value: string): void => {
          this.inputUrl = value;
        });

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(14)
          .fontColor('#A89982')
          .backgroundColor('#EFEBE9')
          .layoutWeight(1)
          .onClick((): void => {
            this.controller.close();
          });

        Button('确定')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#705C53')
          .layoutWeight(1)
          .onClick((): void => {
            if (this.inputUrl.trim()) {
              this.onConfirm(this.inputUrl.trim());
              this.controller.close();
            } else {
              promptAction.showToast({ message: '请输入图片地址' });
            }
          });
      }
      .width('100%')
      .padding({ top: 8, bottom: 20 });
    }
    .padding({ left: 20, right: 20 })
    .backgroundColor(Color.White)
    .borderRadius(20)
    .width('90%');
  }
}

// ==================== AI 建议弹窗 ====================
@CustomDialog
struct AIDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });
  noteId: number = 0;  // 从外部传入
  onApplySummary: (summary: string) => void = () => {};  // 应用摘要回调
  onApplyTodos: (todos: string[]) => void = () => {};    // 应用待办回调

  @State isLoading: boolean = true;
  @State aiResult: AIResult = { keywords: [], labels: [], todos: [], priority: 'normal', summary: '' };
  @State aiError: string = '';
  @State selectedKeywords: Set<number> = new Set();
  @State selectedTodos: Set<number> = new Set();
  @StorageLink('themeBg') themeBg: string = '#F9F8F4';

  async aboutToAppear(): Promise<void> {
    await this.fetchData();
  }

  async fetchData(): Promise<void> {
    this.isLoading = true;
    this.selectedKeywords.clear();
    this.selectedTodos.clear();
    try {
      // 1. 本地抽取
      const extractRes = await httpRequest<AIExtractResponse>(`/notes/${this.noteId}/ai/extract`, 'POST');
      if (extractRes && extractRes.result) {
        this.aiResult = {
          keywords: extractRes.result.keywords || [],
          labels: extractRes.result.labels || [],
          todos: extractRes.result.todos || [],
          priority: extractRes.result.priority || 'normal',
          summary: extractRes.result.summary || ''
        };
      }

      // 2. 云端摘要（可选，失败不影响）
      try {
        const cloudRes = await httpRequest<AISummarizeResponse>(`/notes/${this.noteId}/ai/summarize`, 'POST');
        if (cloudRes && cloudRes.summary) {
          this.aiResult.summary = cloudRes.summary;
          if (cloudRes.keywords && cloudRes.keywords.length) {
            this.aiResult.keywords = cloudRes.keywords;
          }
        }
      } catch (e) {
        const error = e as Error;
        console.warn('cloud summarize failed', error.message);
        this.aiError = '💡 提示: 云端摘要不可用，已使用本地抽取';
      }
    } catch (e) {
      const error = e as Error;
      console.error('AI 抽取失败', error.message);
      this.aiError = '❌ AI 抽取失败，请稍后重试';
    } finally {
      this.isLoading = false;
    }
  }

  async regenerate(): Promise<void> {
    this.isLoading = true;
    try {
      const res = await httpRequest<AIExtractResponse>(`/notes/${this.noteId}/ai/regenerate`, 'POST');
      if (res && res.result) {
        this.aiResult = {
          keywords: res.result.keywords || [],
          labels: res.result.labels || [],
          todos: res.result.todos || [],
          priority: res.result.priority || 'normal',
          summary: this.aiResult.summary
        };
        this.aiError = '';
      }
    } catch (e) {
      const error = e as Error;
      promptAction.showToast({ message: '重新生成失败: ' + error.message });
    } finally {
      this.isLoading = false;
    }
  }

  build(): void {
    Column() {
      Row() {
        Column({ space: 5 }) {
          Text('AI 建议')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3F332D')

          Text('根据当前笔记生成摘要、关键词和待办')
            .fontSize(13)
            .fontColor('#9A8B7A')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('✕')
          .fontSize(16)
          .fontColor('#8E7D6B')
          .width(34)
          .height(34)
          .textAlign(TextAlign.Center)
          .backgroundColor('#F4EFE8')
          .borderRadius(17)
          .onClick(() => this.controller.close())
      }
      .width('100%')
      .padding({ left: 24, right: 20, top: 22, bottom: 14 })

      if (this.isLoading) {
        Column({ space: 14 }) {
          LoadingProgress()
            .width(38)
            .height(38)
            .color('#9B7250')

          Text('AI 正在分析笔记内容...')
            .fontSize(15)
            .fontColor('#8E7D6B')
        }
        .width('100%')
        .height(260)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 18 }) {
            if (this.aiError) {
              Text(this.aiError)
                .fontSize(14)
                .fontColor('#B7791F')
                .width('100%')
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor('#FFF8E8')
                .borderRadius(12)
            }

            Column({ space: 10 }) {
              Row() {
                Text('摘要')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4A3933')

                Blank()

                Text(`${this.aiResult.summary.length}/300`)
                  .fontSize(12)
                  .fontColor('#A89982')
              }
              .width('100%')

              TextArea({ text: this.aiResult.summary, placeholder: '暂无摘要...' })
                .fontSize(15)
                .fontColor('#4A3933')
                .backgroundColor('#FBF8F3')
                .borderRadius(14)
                .border({ width: 1, color: '#EEE3D6' })
                .padding(14)
                .height(118)
                .maxLength(300)
                .showCounter(false)
                .onChange((v: string) => {
                  this.aiResult.summary = v;
                })
            }
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(18)
            .shadow({ radius: 10, color: '#12000000', offsetY: 3 })

            Column({ space: 12 }) {
              Row() {
                Text('关键词')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4A3933')

                Blank()

                Text(`${this.aiResult.keywords.length} 个`)
                  .fontSize(12)
                  .fontColor('#A89982')
              }
              .width('100%')

              Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                ForEach(this.aiResult.keywords, (kw: string, idx: number) => {
                  Row({ space: 6 }) {
                    Text(kw)
                      .fontSize(14)
                      .fontColor('#6B5A42')

                    SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
                      .fontSize(15)
                      .fontColor(['#CBBBA5'])
                      .onClick(() => {
                        this.aiResult.keywords = this.aiResult.keywords.filter((_, i) => i !== idx);
                      })
                  }
                  .padding({ left: 12, right: 10, top: 7, bottom: 7 })
                  .margin({ right: 8, bottom: 8 })
                  .backgroundColor('#F3EBDD')
                  .borderRadius(18)
                }, (kw: string, i: number) => 'kw-' + i)
              }
              .width('100%')
            }
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(18)
            .shadow({ radius: 10, color: '#12000000', offsetY: 3 })

            Column({ space: 12 }) {
              Row() {
                Text('待办事项')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4A3933')

                Blank()

                Text(`${this.aiResult.todos.length} 项`)
                  .fontSize(12)
                  .fontColor('#A89982')
              }
              .width('100%')

              Column({ space: 10 }) {
                ForEach(this.aiResult.todos, (t: string, idx: number) => {
                  Row({ space: 10 }) {
                    Column()
                      .width(8)
                      .height(8)
                      .borderRadius(4)
                      .backgroundColor('#8BA078')
                      .flexShrink(0)

                    TextInput({ text: t })
                      .fontSize(14)
                      .fontColor('#4A3933')
                      .backgroundColor(Color.Transparent)
                      .layoutWeight(1)
                      .onChange((v: string) => {
                        const newTodos = [...this.aiResult.todos];
                        newTodos[idx] = v;
                        this.aiResult.todos = newTodos;
                      })

                    Text('✕')
                      .fontSize(15)
                      .fontColor('#B8A996')
                      .onClick(() => {
                        this.aiResult.todos = this.aiResult.todos.filter((_, i) => i !== idx);
                      })
                  }
                  .width('100%')
                  .padding({ left: 14, right: 12, top: 10, bottom: 10 })
                  .backgroundColor('#FBF8F3')
                  .borderRadius(13)
                }, (t: string, i: number) => 'todo-' + i)

                Row({ space: 6 }) {
                  Text('+')
                    .fontSize(18)
                    .fontColor('#9B7250')

                  Text('添加待办')
                    .fontSize(14)
                    .fontColor('#9B7250')
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
                .justifyContent(FlexAlign.Center)
                .border({ width: 1, color: '#E8DCCA', style: BorderStyle.Dashed })
                .borderRadius(13)
                .onClick(() => {
                  this.aiResult.todos = [...this.aiResult.todos, ''];
                })
              }
              .width('100%')
            }
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(18)
            .shadow({ radius: 10, color: '#12000000', offsetY: 3 })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 6, bottom: 10 })
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .layoutWeight(1)

        Row({ space: 10 }) {
          Button('重新生成')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#6F6254')
            .backgroundColor('#EFE8DD')
            .borderRadius(14)
            .height(42)
            .layoutWeight(1)
            .onClick(() => this.regenerate())

          Button('应用摘要')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#6F6254')
            .backgroundColor('#EFE8DD')
            .borderRadius(14)
            .height(42)
            .layoutWeight(1)
            .onClick(() => {
              this.onApplySummary(this.aiResult.summary);
              this.controller.close();
            })

          Button('作为待办')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#6F5647')
            .borderRadius(14)
            .height(42)
            .layoutWeight(1)
            .onClick(() => {
              this.onApplyTodos(this.aiResult.todos.filter(t => t.trim() !== ''));
              this.controller.close();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 20 })
      }
    }
    .width('92%')
    .height('76%')
    .backgroundColor(this.themeBg)
    .borderRadius(24)
    .clip(true)
  }
  // build(): void {
  //   Column({ space: 12 }) {
  //     // 标题栏
  //     Row() {
  //       Text('🤖 AI 建议')
  //         .fontSize(18)
  //         .fontWeight(FontWeight.Bold)
  //         .fontColor('#4A3933');
  //       Blank();
  //       SymbolGlyph($r('sys.symbol.xmark'))
  //         .fontSize(20)
  //         .fontColor(['#A89982'])
  //         .onClick(() => this.controller.close());
  //     }
  //     .width('100%')
  //     .padding({ left: 12, right: 12, top: 12, bottom: 12 });
  //
  //     Divider().color('#EFEBE9');
  //
  //     if (this.isLoading) {
  //       Column({ space: 10 }) {
  //         LoadingProgress().width(40).height(40).color('#705C53');
  //         Text('AI 正在思考...').fontSize(14).fontColor('#A89982');
  //       }
  //       .padding(40)
  //       .width('100%')
  //       .justifyContent(FlexAlign.Center)
  //     } else {
  //       Scroll() {
  //         Column({ space: 16 }) {
  //           // 摘要区域
  //           Column({ space: 8 }) {
  //             Row({ space: 6 }) {
  //               Text('📝 摘要').fontSize(14).fontColor('#4A3933').fontWeight(FontWeight.Medium);
  //               Text(`(${this.aiResult.summary.length}/300)`).fontSize(11).fontColor('#A89982');
  //             }
  //             TextArea({ text: this.aiResult.summary, placeholder: '摘要内容...' })
  //               .fontSize(13)
  //               .fontColor('#4A3933')
  //               .backgroundColor('#F9F8F4')
  //               .borderRadius(8)
  //               .padding(10)
  //               .height(100)
  //               .maxLength(300)
  //               .showCounter(false)
  //               .onChange((v: string) => { this.aiResult.summary = v; });
  //           }
  //
  //           if (this.aiError) {
  //             Row() {
  //               Text(this.aiError).fontSize(12).fontColor('#E67E22')
  //                 .layoutWeight(1);
  //             }
  //             .padding(10)
  //             .backgroundColor('#FFF3E0')
  //             .borderRadius(6)
  //             .width('100%');
  //           }
  //
  //           // 关键词标签区域
  //           Column({ space: 8 }) {
  //             Row({ space: 6 }) {
  //               Text('🏷️ 关键词').fontSize(14).fontColor('#4A3933').fontWeight(FontWeight.Medium);
  //               Text(`(${this.aiResult.keywords.length})`).fontSize(11).fontColor('#A89982');
  //             }
  //
  //             Flex({ wrap: FlexWrap.Wrap }) {
  //               ForEach(this.aiResult.keywords, (kw: string, idx: number) => {
  //                 Row({ space: 4 }) {
  //                   Text(kw)
  //                     .fontSize(12)
  //                     .fontColor('#705C53')
  //                     .maxLines(1)
  //                     .textOverflow({ overflow: TextOverflow.Ellipsis });
  //
  //                   SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
  //                     .fontSize(14)
  //                     .fontColor(['#A89982'])
  //                     .onClick(() => {
  //                       const newKw = this.aiResult.keywords.filter((_, i) => i !== idx);
  //                       this.aiResult.keywords = newKw;
  //                     });
  //                 }
  //                 .padding({ left: 10, right: 8, top: 6, bottom: 6 })
  //                 .margin({ right: 8, bottom: 8 })
  //                 .backgroundColor('#EFEBE9')
  //                 .borderRadius(14);
  //               }, (kw: string, i: number) => 'kw-' + i)
  //             }
  //             .width('100%')
  //           }
  //
  //           // 待办项区域
  //           Column({ space: 8 }) {
  //             Row({ space: 6 }) {
  //               Text('✓ 待办').fontSize(14).fontColor('#4A3933').fontWeight(FontWeight.Medium);
  //               Text(`(${this.aiResult.todos.length})`).fontSize(11).fontColor('#A89982');
  //             }
  //
  //             Column({ space: 6 }) {
  //               ForEach(this.aiResult.todos, (t: string, idx: number) => {
  //                 Row({ space: 8 }) {
  //                   Checkbox()
  //                     .width(18)
  //                     .height(18)
  //                     .selectedColor('#705C53');
  //                   TextInput({ text: t })
  //                     .fontSize(13)
  //                     .fontColor('#4A3933')
  //                     .backgroundColor(Color.Transparent)
  //                     .layoutWeight(1)
  //                     .onChange((v: string) => {
  //                       const newTodos = [...this.aiResult.todos];
  //                       newTodos[idx] = v;
  //                       this.aiResult.todos = newTodos;
  //                     });
  //                   SymbolGlyph($r('sys.symbol.trash'))
  //                     .fontSize(16)
  //                     .fontColor(['#C0392B'])
  //                     .onClick(() => {
  //                       const newTodos = this.aiResult.todos.filter((_, i) => i !== idx);
  //                       this.aiResult.todos = newTodos;
  //                     });
  //                 }
  //                 .padding({ left: 10, right: 10, top: 8, bottom: 8 })
  //                 .backgroundColor('#F9F8F4')
  //                 .borderRadius(6)
  //                 .width('100%');
  //               }, (t: string, i: number) => 'todo-' + i)
  //             }
  //             .width('100%');
  //
  //             // 添加待办按钮
  //             Row({ space: 8 }) {
  //               SymbolGlyph($r('sys.symbol.plus_circle'))
  //                 .fontSize(16)
  //                 .fontColor(['#705C53']);
  //               Text('添加待办')
  //                 .fontSize(13)
  //                 .fontColor('#705C53');
  //             }
  //             .padding({ left: 12, right: 12, top: 8, bottom: 8 })
  //             .backgroundColor('#EFEBE9')
  //             .borderRadius(6)
  //             .width('100%')
  //             .justifyContent(FlexAlign.Center)
  //             .onClick(() => {
  //               this.aiResult.todos = [...this.aiResult.todos, ''];
  //             });
  //           }
  //         }
  //         .padding({ left: 12, right: 12 })
  //         .width('100%');
  //       }
  //       .scrollable(ScrollDirection.Vertical)
  //       .scrollBar(BarState.Off)
  //       .layoutWeight(1);
  //
  //       // 底部操作按钮
  //       Row({ space: 8 }) {
  //         Button('重新生成')
  //           .fontSize(13)
  //           .fontColor('#FFF')
  //           .backgroundColor('#ffb79898')
  //           .onClick(() => this.regenerate())
  //           .layoutWeight(1);
  //
  //         Button('应用摘要')
  //           .fontSize(13)
  //           .fontColor('#FFF')
  //           .backgroundColor('#ffa78b61')
  //           .onClick(() => {
  //             this.onApplySummary(this.aiResult.summary);
  //             this.controller.close();
  //           })
  //           .layoutWeight(1);
  //
  //         Button('作为待办')
  //           .fontSize(13)
  //           .fontColor('#FFF')
  //           .backgroundColor('#ffd6b857')
  //           .onClick(() => {
  //             this.onApplyTodos(this.aiResult.todos.filter(t => t.trim() !== ''));
  //             this.controller.close();
  //           })
  //           .layoutWeight(1);
  //       }
  //       .padding({ left: 12, right: 12, top: 8, bottom: 8 })
  //       .width('100%');
  //     }
  //   }
  //   .padding({ left: 16, right: 16, top: 12, bottom: 16 })
  //   .backgroundColor(Color.White)
  //   .borderRadius(20)
  //   .width('90%')
  //   .height('80%');
  // }
}

interface AIResult {
  keywords: string[];
  labels: string[];
  todos: string[];
  priority: string;
  summary: string;
}

// ==================== 笔记编辑页 ====================
@Entry
@Component
struct NoteEdit {
  @State noteId: number | null = null;
  @State title: string = '';
  @State summary: string = '';
  @State view_type: string = 'default';
  @State imagePaths: string[] = [];
  @State tags: Tag[] = [];
  @State tagId: number | null = null;
  @State isSaving: boolean = false;
  @State templates: NoteTemplate[] = [];
  @State isBold: boolean = false;
  @State currentColor: string = '#4A3933';
  @State aiResult: AIResult = { keywords: [], labels: [], todos: [], priority: 'normal', summary: '' };
  @State aiError: string = '';
  @StorageLink('themeBg') themeBg: string = '#F9F8F4';

  private richController: RichEditorController = new RichEditorController();
  private plainContent: string = '';
  private aiDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, number | string>;
    if (params && params.id) {
      this.noteId = params.id as number;
      this.fetchNote(this.noteId);
    }
    this.fetchTags();
    this.fetchTemplates();
  }

  tagNameById(tagId: number | null): string {
    if (tagId === null) return '';
    const found = this.tags.find(t => t.id === tagId);
    return found ? found.name : '';
  }

  extractPlainText(): string {
    try {
      const spans = this.richController.getSpans();
      let text = '';
      for (const span of spans) {
        if (typeof (span as RichEditorTextSpanResult).value !== 'undefined') {
          text += (span as RichEditorTextSpanResult).value;
        }
      }
      return text;
    } catch (e) {
      const error = e as Error;
      console.error('提取纯文本失败', error.message);
      return this.plainContent;
    }
  }

  validateAndSave(): void {
    if (!this.title.trim()) {
      promptAction.showToast({ message: '🦙：给灵感起个名字吧（标题不能为空）' });
      return;
    }
    this.saveNote();
  }

  // ── 格式操作 ──
  toggleBold(): void {
    this.isBold = !this.isBold;
    this.richController.setTypingStyle({
      fontWeight: this.isBold ? FontWeight.Bold : FontWeight.Normal
    });
    const sel = this.richController.getSelection();
    if (sel && sel.selection[0] !== sel.selection[1]) {
      this.richController.updateSpanStyle({
        start: sel.selection[0],
        end: sel.selection[1],
        textStyle: {
          fontWeight: this.isBold ? FontWeight.Bold : FontWeight.Normal
        }
      });
    }
  }

  insertHeading(level: number): void {
    const sizes: number[] = [26, 20, 17];
    const fontSize = sizes[level - 1];
    this.richController.addTextSpan('\n', {
      style: { fontSize: 16, fontColor: '#4A3933' }
    });
    this.richController.setTypingStyle({
      fontSize: fontSize,
      fontColor: '#4A3933',
      fontWeight: FontWeight.Bold
    });
  }

  insertNote(): void {
    this.richController.addTextSpan('\n⚠️ 注意：', {
      style: { fontSize: 15, fontColor: '#E67E22', fontWeight: FontWeight.Bold }
    });
    this.richController.setTypingStyle({
      fontSize: 15,
      fontColor: '#E67E22',
      fontWeight: FontWeight.Normal
    });
  }

  insertQuote(): void {
    this.richController.addTextSpan('\n❝  ', {
      style: { fontSize: 15, fontColor: '#A89982', fontStyle: FontStyle.Italic }
    });
    this.richController.setTypingStyle({
      fontSize: 15,
      fontColor: '#A89982',
      fontStyle: FontStyle.Italic
    });
  }

  insertTime(): void {
    const now = new Date();
    const pad = (n: number): string => n < 10 ? '0' + n : '' + n;
    const timeStr = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}`;
    this.richController.addTextSpan(` 🕐 ${timeStr} `, {
      style: { fontSize: 13, fontColor: '#A89982' }
    });
    this.richController.setTypingStyle({
      fontSize: 16,
      fontColor: this.currentColor,
      fontWeight: this.isBold ? FontWeight.Bold : FontWeight.Normal
    });
  }

  insertDivider(): void {
    this.richController.addTextSpan('\n────────────────────\n', {
      style: { fontSize: 14, fontColor: '#D2C4B0' }
    });
    this.richController.setTypingStyle({
      fontSize: 16,
      fontColor: '#4A3933',
      fontWeight: FontWeight.Normal,
      fontStyle: FontStyle.Normal
    });
  }

  applyColor(color: string): void {
    this.currentColor = color;
    this.richController.setTypingStyle({ fontColor: color });
    const sel = this.richController.getSelection();
    if (sel && sel.selection[0] !== sel.selection[1]) {
      this.richController.updateSpanStyle({
        start: sel.selection[0],
        end: sel.selection[1],
        textStyle: { fontColor: color }
      });
    }
  }

  resetStyle(): void {
    this.isBold = false;
    this.currentColor = '#4A3933';
    this.richController.setTypingStyle({
      fontSize: 16,
      fontColor: '#4A3933',
      fontWeight: FontWeight.Normal,
      fontStyle: FontStyle.Normal
    });
  }

  openTemplateDialog(): void {
    let dController: CustomDialogController | undefined = undefined;
    dController = new CustomDialogController({
      builder: TemplateDialog({
        templates: this.templates,
        controller: dController,
        onSelect: (skeleton: string) => {
          this.richController.addTextSpan('\n' + skeleton, {
            style: { fontSize: 16, fontColor: '#4A3933' }
          });
          promptAction.showToast({ message: '模板已应用 ✓' });
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 }
    });
    dController.open();
  }

  openColorPicker(): void {
    let dController: CustomDialogController | undefined = undefined;
    dController = new CustomDialogController({
      builder: PickerDialog({
        controller: dController,
        onSelect: (color: string): void => {
          this.applyColor(color);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 }
    });
    dController.open();
  }

  build(): void {
    Column() {
      // 顶部导航栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor(['#705C53'])
          .onClick(() => router.back());

        Blank();

        Text(this.noteId ? '编辑笔记' : '新灵感')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4A3933');

        Blank();

        if (this.isSaving) {
          LoadingProgress().width(24).height(24).color('#705C53');
        } else {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(24)
            .fontColor(['#705C53'])
            .onClick(() => this.validateAndSave());
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 10 });

      // 标题
      TextInput({ text: this.title, placeholder: '灵感标题...' })
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .placeholderColor('#D2C4B0')
        .fontColor('#4A3933')
        .backgroundColor(Color.Transparent)
        .width('100%')
        .padding({ left: 24, right: 24 })
        .onChange((v: string) => this.title = v);

      // 摘要
      TextInput({ text: this.summary, placeholder: '添加一段简短的摘要（可选）' })
        .fontSize(14)
        .fontColor('#887A73')
        .placeholderColor('#D2C4B0')
        .backgroundColor(Color.Transparent)
        .width('100%')
        .padding({ left: 24, right: 24 })
        .onChange((v: string) => this.summary = v);

      Divider().color('#EFEBE9').strokeWidth(1).margin({ left: 24, right: 24, top: 8, bottom: 4 });

      // 标签行
      Row({ space: 8 }) {
        Text('🏷️').fontSize(16);
        List({ space: 8 }) {
          ForEach(this.tags, (tag: Tag) => {
            ListItem() {
              Text(tag.name)
                .fontSize(12)
                .fontColor(this.tagId === tag.id ? '#FFF' : '#A89982')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor(this.tagId === tag.id ? '#705C53' : '#FFF')
                .borderRadius(15)
                .border({ width: 1, color: this.tagId === tag.id ? '#705C53' : '#EFEBE9' })
                .onClick(() => {
                  this.tagId = (this.tagId === tag.id) ? null : tag.id;
                });
            }
          }, (tag: Tag) => tag.id.toString());
        }
        .listDirection(Axis.Horizontal)
        .height(35)
        .layoutWeight(1)
        .scrollBar(BarState.Off);

        if (this.tagId !== null && this.tagNameById(this.tagId)) {
          Row({ space: 4 }) {
            Circle({ width: 6, height: 6 }).fill('#705C53');
            Text(this.tagNameById(this.tagId))
              .fontSize(11)
              .fontColor('#705C53');
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#EFEBE9')
          .borderRadius(10);
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24 });

      Divider().color('#EFEBE9').strokeWidth(1).margin({ left: 24, right: 24, top: 8, bottom: 0 });

      // RichEditor 正文
      RichEditor({ controller: this.richController })
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 24, right: 24, top: 12, bottom: 12 })
        .backgroundColor(Color.Transparent)
        .placeholder('在此输入你的想法，尽情记录灵感...', {
          font: { size: 16 },
          fontColor: '#D2C4B0'
        })
        .onReady(() => {
          this.richController.setTypingStyle({
            fontSize: 16,
            fontColor: '#4A3933',
            fontWeight: FontWeight.Normal
          });
        });

      // 图片预览区域
      Column() {
        if (this.imagePaths.length > 0) {
          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.imagePaths, (path: string, index: number) => {
                Stack({ alignContent: Alignment.TopEnd }) {
                  Image(path)
                    .width(100)
                    .height(100)
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)
                    .backgroundColor('#F0F0F0')
                    .alt($r('sys.media.ohos_app_icon'))
                    .onError(() => {
                      console.error('图片加载失败:', path);
                    });

                  SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
                    .fontSize(20)
                    .fontColor(['#C0392B'])
                    .onClick(() => {
                      this.imagePaths = this.imagePaths.filter((_, i) => i !== index);
                    });
                }
                .width(100)
                .height(100);
              }, (path: string) => path);
            }
            .padding({ left: 24, right: 24, top: 10, bottom: 10 });
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .height(120);
        }
      }
      .width('100%')
      .backgroundColor(this.imagePaths.length > 0 ? '#F9F8F4' : Color.Transparent);

      // 格式工具栏
      Scroll() {
        Row({ space: 2 }) {
          this.ToolBtn('B', this.isBold, () => this.toggleBold(), true);
          this.ToolBtn('H1', false, () => this.insertHeading(1), false);
          this.ToolBtn('H2', false, () => this.insertHeading(2), false);
          this.ToolBtn('H3', false, () => this.insertHeading(3), false);
          this.ToolBtn('⚠️', false, () => this.insertNote(), false);
          this.ToolBtn('❝', false, () => this.insertQuote(), false);
          this.ToolBtn('🕐', false, () => this.insertTime(), false);
          this.ToolBtn('──', false, () => this.insertDivider(), false);
          this.ColorToolBtn();
          this.ToolBtn('Aa', false, () => this.resetStyle(), false);
          this.ToolBtn('📋', false, () => this.openTemplateDialog(), false);
          this.ToolBtn('AI', false, () => this.openAIDialog(), false);
        }
        .padding({ left: 12, right: 12 });
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(48)
      .backgroundColor('#FAFAF8')
      .border({ width: { top: 1 }, color: '#EFEBE9' });

      // 底部操作栏
      Row() {
        Column({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.figure'))
            .fontSize(20)
            .fontColor(['#705C53']);
          Text('图片')
            .fontSize(10)
            .fontColor('#A89982');
        }
        .layoutWeight(1)
        .padding({ top: 8, bottom: 8 })
        .onClick(() => {
          let imgController: CustomDialogController | undefined = undefined;
          imgController = new CustomDialogController({
            builder: ImageSourceDialog({
              controller: imgController,
              onSelect: (type: 'album' | 'camera' | 'url') => {
                if (type === 'album') {
                  this.handleAlbum();
                } else if (type === 'camera') {
                  this.handleCamera();
                } else if (type === 'url') {
                  this.handleUrlInput();
                }
              }
            }),
            alignment: DialogAlignment.Bottom,
            offset: { dx: 0, dy: -20 },
            autoCancel: true,
            customStyle: true
          });
          imgController.open();
        });

        Column({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(20)
            .fontColor(['#C0392B']);
          Text('清空')
            .fontSize(10)
            .fontColor('#C0392B');
        }
        .layoutWeight(1)
        .padding({ top: 8, bottom: 8 })
        .onClick(() => {
          promptAction.showDialog({
            title: '清空正文',
            message: '确定要清空所有正文内容吗？',
            buttons: [
              { text: '取消', color: '#A89982' },
              { text: '清空', color: '#C0392B' }
            ]
          }).then((result: DialogResult) => {
            if (result.index === 1) {
              this.richController.deleteSpans();
            }
          });
        });

        Column({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle'))
            .fontSize(20)
            .fontColor(['#705C53']);
          Text('保存')
            .fontSize(10)
            .fontColor('#705C53')
            .fontWeight(FontWeight.Medium);
        }
        .layoutWeight(1)
        .padding({ top: 8, bottom: 8 })
        .onClick(() => this.validateAndSave());

        Column({ space: 4 }) {
          Text('🤖')
            .fontSize(20);
          Text('AI')
            .fontSize(10)
            .fontColor('#A89982');
        }
        .layoutWeight(1)
        .padding({ top: 8, bottom: 8 })
        .onClick(() => this.openAIDialog());
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .border({ width: { top: 1 }, color: '#EFEBE9' });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBg);
  }

  @Builder
  ToolBtn(label: string, active: boolean, action: () => void, isBoldStyle: boolean): void {
    Text(label)
      .fontSize(isBoldStyle ? 15 : 14)
      .fontWeight(isBoldStyle ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(active ? '#FFF' : '#705C53')
      .width(40)
      .height(34)
      .textAlign(TextAlign.Center)
      .backgroundColor(active ? '#705C53' : '#EFEBE9')
      .borderRadius(8)
      .margin(3)
      .onClick(action);
  }

  @Builder
  ColorToolBtn(): void {
    Column({ space: 2 }) {
      Text('A')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentColor);
      Column()
        .width(22)
        .height(3)
        .backgroundColor(this.currentColor)
        .borderRadius(2);
    }
    .width(40)
    .height(34)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#EFEBE9')
    .borderRadius(8)
    .margin(3)
    .onClick(() => this.openColorPicker());
  }

  // ── 数据方法 ──
  async fetchNote(id: number): Promise<void> {
    try {
      const note = await httpRequest<NoteResponse>(`/notes/${id}`, 'GET');
      if (!note) {
        promptAction.showToast({ message: '未找到该笔记' });
        return;
      }

      this.title = note.title || '';
      this.summary = note.summary || '';
      this.view_type = note.view_type || 'default';
      this.tagId = note.tag_id ?? null;
      this.plainContent = note.content || '';
      if (note.image_paths) {
        this.imagePaths = note.image_paths.split(',').filter(p => p.trim() !== '');
      }
      if (this.plainContent) {
        this.richController.addTextSpan(this.plainContent, {
          style: { fontSize: 16, fontColor: '#4A3933' }
        });
      }
    } catch (e) {
      const error = e as Error;
      console.error('加载笔记失败', error.message);
      promptAction.showToast({ message: '加载笔记失败' });
    }
  }

  async fetchTags(): Promise<void> {
    try {
      const data = await httpRequest<Tag[]>('/tags/', 'GET');
      this.tags = data ?? [];
    } catch (e) {
      const error = e as Error;
      console.error('加载标签失败', error.message);
    }
  }

  async fetchTemplates(): Promise<void> {
    try {
      const data = await httpRequest<NoteTemplate[]>('/templates/', 'GET');
      this.templates = data ?? [];
    } catch (e) {
      const error = e as Error;
      console.error('获取模板失败', error.message);
    }
  }

  async saveNote(): Promise<void> {
    this.isSaving = true;
    try {
      const plainText = this.extractPlainText();
      const payload: NoteCreateRequest = {
        title: this.title.trim(),
        summary: this.summary.trim(),
        view_type: this.view_type,
        content: plainText,
        image_paths: this.imagePaths.length ? this.imagePaths.join(',') : undefined,
        tag_id: this.tagId
      };
      if (this.noteId === null) {
        await httpRequest<NoteResponse>('/notes/', 'POST', payload);
      } else {
        await httpRequest<NoteResponse>(`/notes/${this.noteId}`, 'PUT', payload);
      }
      promptAction.showToast({ message: '灵感已妥善保管 ✓' });
      router.back();
    } catch (e) {
      const error = e as Error;
      console.error('保存失败', error.message);
      promptAction.showToast({ message: '保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  // ── AI 集成方法 ──
  async openAIDialog(): Promise<void> {
    if (this.noteId === null) {
      promptAction.showToast({ message: '请先保存笔记以使用 AI 功能' });
      return;
    }

    if (this.aiDialogController) {
      this.aiDialogController.close();
    }
    this.aiDialogController = new CustomDialogController({
      builder: AIDialog({
        noteId: this.noteId,
        onApplySummary: (summary: string) => {
          this.summary = summary;
          promptAction.showToast({ message: '摘要已写回，可继续编辑后保存' });
        },
        onApplyTodos: (todos: string[]) => {
          if (todos.length === 0) {
            promptAction.showToast({ message: '没有待办项可应用' });
            return;
          }
          this.applyTodosFromList(todos);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.aiDialogController.open();
  }

  // 新增方法：应用待办列表
  async applyTodosFromList(todos: string[]): Promise<void> {
    try {
      const payload: TodoApplyPayload = { todos };
      const created = await httpRequest<TodoApplyResponse>(`/notes/${this.noteId}/ai/apply_todos`, 'POST', payload);
      if (created) {
        promptAction.showToast({ message: '已创建待办 ✓' });
      } else {
        promptAction.showToast({ message: '创建待办失败' });
      }
    } catch (e) {
      const error = e as Error;
      console.error('applyTodos failed', error.message);
      promptAction.showToast({ message: '写入待办失败' });
    }
  }

  applySummaryToNote(): void {
    if (this.aiResult && this.aiResult.summary) {
      this.summary = this.aiResult.summary;
      promptAction.showToast({ message: '摘要已写回，可继续编辑后保存' });
    } else {
      promptAction.showToast({ message: '无可用摘要' });
    }
  }

  async applyTodos(): Promise<void> {
    if (!this.aiResult || !this.aiResult.todos || this.aiResult.todos.length === 0) {
      promptAction.showToast({ message: '没有待办建议可写入' });
      return;
    }
    try {
      const payload: TodoApplyPayload = { todos: this.aiResult.todos };
      const created = await httpRequest<TodoApplyResponse>(`/notes/${this.noteId}/ai/apply_todos`, 'POST', payload);
      if (created) {
        promptAction.showToast({ message: '已创建待办 ✓' });
      } else {
        promptAction.showToast({ message: '创建待办失败' });
      }
    } catch (e) {
      const error = e as Error;
      console.error('applyTodos failed', error.message);
      promptAction.showToast({ message: '写入待办失败' });
    }
  }

  addTodoLine(): void {
    this.aiResult.todos = [...this.aiResult.todos, ''];
  }

  removeTodoLine(index: number): void {
    this.aiResult.todos = this.aiResult.todos.filter((_, i) => i !== index);
  }

  updateTodoLine(index: number, value: string): void {
    const newTodos = [...this.aiResult.todos];
    newTodos[index] = value;
    this.aiResult.todos = newTodos;
  }

  updateKeyword(index: number, value: string): void {
    const newKeywords = [...this.aiResult.keywords];
    newKeywords[index] = value;
    this.aiResult.keywords = newKeywords;
  }

  // ── 图片上传相关 ──
  private currentUploadTask: commonRequest.UploadTask | null = null;

  async uploadToBackend(internalUri: string): Promise<void> {
    const SERVER_URL = "http://10.0.2.2:8000";
    try {
      const uploadConfig: commonRequest.UploadConfig = {
        url: `${SERVER_URL}/files/upload`,
        header: { 'Accept': '*/*' },
        method: 'POST',
        files: [{
          filename: `upload_${Date.now()}.jpg`,
          name: 'file',
          uri: internalUri,
          type: 'image/jpeg'
        }],
        data: []
      };

      this.currentUploadTask = await commonRequest.uploadFile(getContext(this), uploadConfig);

      this.currentUploadTask.on('progress', (uploadedSize: number, totalSize: number) => {
        console.info(`上传中: ${uploadedSize}/${totalSize}`);
      });

      this.currentUploadTask.on('headerReceive', (header: object) => {
        const headers = header as Record<string, string>;
        console.info('接收到响应头:', JSON.stringify(headers));
        try {
          const bodyStr = headers['body'] ?? headers['Body'] ?? '';
          if (bodyStr) {
            const response = JSON.parse(bodyStr) as UploadResponse;
            const purePath = response.url.startsWith('/') ? response.url : `/${response.url}`;
            const fullImageUrl = 'http://10.0.2.2:8000' + purePath;
            console.info('headerReceive 解析图片路径:', fullImageUrl);
            this.imagePaths = [...this.imagePaths, fullImageUrl];
            promptAction.showToast({ message: '图片上传成功 ✓' });
          }
        } catch (e) {
          const error = e as Error;
          console.error('headerReceive 解析失败:', error.message);
        }
      });

      this.currentUploadTask.on('complete', (taskStates: Array<commonRequest.TaskState>) => {
        console.info('任务完成状态:', JSON.stringify(taskStates));
        if (taskStates.length > 0 && taskStates[0].message) {
          try {
            const response = JSON.parse(taskStates[0].message) as UploadResponse;
            const purePath = response.url.startsWith('/') ? response.url : `/${response.url}`;
            const fullImageUrl = 'http://10.0.2.2:8000' + purePath;
            this.imagePaths = [...this.imagePaths, fullImageUrl];
            promptAction.showToast({ message: '图片上传成功 ✓' });
          } catch (e) {
            const error = e as Error;
            console.error('解析失败:', error.message);
            promptAction.showToast({ message: '解析响应失败' });
          }
        }
      });

      this.currentUploadTask.on('fail', (taskStates: Array<commonRequest.TaskState>) => {
        console.error('上传彻底失败:', JSON.stringify(taskStates));
        promptAction.showToast({ message: '上传失败' });
      });
    } catch (err) {
      const error = err as Error;
      console.error('创建上传任务崩溃:', error.message);
    }
  }

  async prepareInternalFile(uri: string): Promise<string> {
    const context = getContext(this);
    const fileName = `upload_${Date.now()}.jpg`;
    const cacheDir = context.cacheDir;
    const destPath = `${cacheDir}/${fileName}`;

    try {
      const srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const destFile = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      fs.copyFileSync(srcFile.fd, destFile.fd);
      fs.closeSync(srcFile.fd);
      fs.closeSync(destFile.fd);
      return `internal://cache/${fileName}`;
    } catch (e) {
      const error = e as Error;
      console.error('文件处理失败:', error.message);
      throw new Error('文件拷贝失败');
    }
  }

  async handleCamera(): Promise<void> {
    const pickerProfile: cameraPicker.PickerProfile = { cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK };
    const result = await cameraPicker.pick(getContext(this), [cameraPicker.PickerMediaType.PHOTO], pickerProfile);
    if (result.resultUri) {
      const internalPath = await this.prepareInternalFile(result.resultUri);
      this.uploadToBackend(internalPath);
    }
  }

  async handleAlbum(): Promise<void> {
    const photoPicker = new photoAccessHelper.PhotoViewPicker();
    const result = await photoPicker.select({ MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, maxSelectNumber: 1 });
    if (result.photoUris.length > 0) {
      const internalPath = await this.prepareInternalFile(result.photoUris[0]);
      this.uploadToBackend(internalPath);
    }
  }

  handleUrlInput(): void {
    let urlController: CustomDialogController | undefined = undefined;
    urlController = new CustomDialogController({
      builder: UrlInputDialog({
        controller: urlController,
        onConfirm: (url: string): void => {
          this.processImageUrl(url);
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: true
    });
    urlController.open();
  }

  async processImageUrl(url: string): Promise<void> {
    try {
      const urlPattern: RegExp = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/;
      if (!urlPattern.test(url)) {
        promptAction.showToast({ message: '图片地址格式不正确' });
        return;
      }
      this.imagePaths = [...this.imagePaths, url];
      promptAction.showToast({ message: '图片 URL 已添加 ✓' });
    } catch (err) {
      const error = err as Error;
      console.error('处理图片 URL 失败', error.message);
      promptAction.showToast({ message: '图片处理失败' });
    }
  }
}
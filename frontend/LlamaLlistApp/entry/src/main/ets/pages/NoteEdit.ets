import { request as httpRequest } from '../common/network/httpClient';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Tag } from '../models/Tag';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';
import { cameraPicker, camera } from '@kit.CameraKit';
import commonRequest from '@ohos.request';
import { extractKeywordsNative } from '../common/native/KeywordNative';
import util from '@ohos.util';
import { common } from '@kit.AbilityKit';

const IMPORT_ALLOWED_SUFFIXES: string[] = ['md', 'txt', 'word', 'doc', 'docx'];

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
  description?: string;
  sort_order?: number;
  is_system?: boolean;
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
  todos?: string[];
}

interface TodoApplyPayload {
  todos: string[];
}

interface TodoApplyResponse {
  count?: number;
}

interface UploadConfigFile {
  filename: string;
  name: string;
  uri: string;
  type: string;
}

interface UploadRequestData {
  name: string;
  value: string;
}

interface UploadConfig {
  url: string;
  header: Record<string, string>;
  method: string;
  files: UploadConfigFile[];
  data: UploadRequestData[];
}

interface UploadTaskState {
  message?: string;
}

// 对话框结果类型
interface DialogResult {
  index: number;
}

interface FileResult {
  uri: string;
  fileName: string;
}

interface ImportExportResult {
  format: 'md' | 'txt' | 'word';
  content: string;
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
                  if (item.description && item.description.trim() !== '') {
                    Text(item.description)
                      .fontSize(11)
                      .fontColor('#B7A58F')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
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

@CustomDialog
struct ImportDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });
  onConfirm: (result: ImportExportResult) => void = () => {};
  onPickFile: (format: 'md' | 'txt' | 'word') => void = () => {};
  @State format: 'md' | 'txt' | 'word' = 'md';
  @State content: string = '';

  build(): void {
    Column({ space: 12 }) {
      Text('导入笔记')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3933');

      Row({ space: 8 }) {
        this.FormatBtn('md')
        this.FormatBtn('txt')
        this.FormatBtn('word')
      }
      .width('100%');

      Row({ space: 8 }) {
        Button('选择文件导入')
          .layoutWeight(1)
          .backgroundColor('#EFEBE9')
          .fontColor('#705C53')
          .onClick(() => {
            this.onPickFile(this.format);
          })
      }
      .width('100%');

      TextArea({ text: this.content, placeholder: '粘贴要导入的内容' })
        .fontSize(14)
        .fontColor('#4A3933')
        .backgroundColor('#F9F8F4')
        .borderRadius(10)
        .padding(10)
        .height(180)
        .onChange((v: string) => this.content = v);

      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor('#EFEBE9')
          .fontColor('#705C53')
          .onClick(() => this.controller.close())
        Button('导入')
          .layoutWeight(1)
          .backgroundColor('#705C53')
          .fontColor('#FFF')
          .onClick(() => {
            this.onConfirm({ format: this.format, content: this.content });
            this.controller.close();
          })
      }
      .width('100%')
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .width('92%');
  }

  @Builder
  FormatBtn(v: 'md' | 'txt' | 'word'): void {
    Text(v.toUpperCase())
      .fontSize(12)
      .fontColor(this.format === v ? '#FFFFFF' : '#705C53')
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.format === v ? '#705C53' : '#EFEBE9')
      .borderRadius(10)
      .onClick(() => this.format = v)
  }
}

@CustomDialog
struct ExportDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });
  defaultContent: string = '';
  onConfirm: (result: ImportExportResult) => void = () => {};
  @State format: 'md' | 'txt' | 'word' = 'md';
  @State content: string = '';

  aboutToAppear(): void {
    this.content = this.defaultContent;
  }

  build(): void {
    Column({ space: 12 }) {
      Text('导出笔记')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3933');

      Row({ space: 8 }) {
        this.FormatBtn('md')
        this.FormatBtn('txt')
        this.FormatBtn('word')
      }
      .width('100%');

      TextArea({ text: this.content, placeholder: '' })
        .fontSize(14)
        .fontColor('#4A3933')
        .backgroundColor('#F9F8F4')
        .borderRadius(10)
        .padding(10)
        .height(180)
        .onChange((v: string) => this.content = v);

      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor('#EFEBE9')
          .fontColor('#705C53')
          .onClick(() => this.controller.close())
        Button('导出')
          .layoutWeight(1)
          .backgroundColor('#705C53')
          .fontColor('#FFF')
          .onClick(() => {
            this.onConfirm({ format: this.format, content: this.content });
            this.controller.close();
          })
      }
      .width('100%')
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .width('92%');
  }

  @Builder
  FormatBtn(v: 'md' | 'txt' | 'word'): void {
    Text(v.toUpperCase())
      .fontSize(12)
      .fontColor(this.format === v ? '#FFFFFF' : '#705C53')
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.format === v ? '#705C53' : '#EFEBE9')
      .borderRadius(10)
      .onClick(() => this.format = v)
  }
}

// ==================== AI 建议弹窗 ====================
@CustomDialog
struct AIDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });
  noteId: number = 0;
  sourceText: string = '';
  onApplySummary: (summary: string) => void = () => {};
  onApplyTodos: (todos: string[]) => void = () => {};

  @State isLoading: boolean = true;
  @State localAIStatus: string = 'idle';
  @State cloudAIStatus: string = 'idle';
  @State aiResult: AIResult = { keywords: [], labels: [], todos: [], priority: 'normal', summary: '' };
  @State keywordSource: 'native' | 'fallback' = 'fallback';
  @State aiError: string = '';
  @State cloudNotice: string = '';
  @StorageLink('themeBg') themeBg: string = '#F9F8F4';

  async aboutToAppear(): Promise<void> {
    await this.fetchData();
  }

  normalizeList(list: string[]): string[] {
    const result: string[] = [];
    for (let i = 0; i < list.length; i++) {
      const item = (list[i] || '').trim();
      if (item.length > 0 && result.indexOf(item) < 0) {
        result.push(item);
      }
    }
    return result;
  }

  normalizeSummary(summary: string): string {
    const text = (summary || '').trim();
    if (text.length > 300) {
      this.cloudNotice = '云端摘要较长，已自动截断到 300 字，可继续手动编辑。';
      return text.substring(0, 300);
    }
    return text;
  }

  statusText(status: string): string {
    if (status === 'loading') return '生成中';
    if (status === 'success') return '已完成';
    if (status === 'empty') return '无结果';
    if (status === 'timeout') return '超时';
    if (status === 'failed') return '异常';
    return '等待中';
  }

  priorityText(priority: string): string {
    if (priority === 'high' || priority === 'important_urgent') return '高优先级';
    if (priority === 'medium' || priority === 'important_not_urgent') return '中优先级';
    if (priority === 'low') return '低优先级';
    return '普通优先级';
  }

  async fetchData(): Promise<void> {
    this.isLoading = true;
    this.aiError = '';
    this.cloudNotice = '';
    this.localAIStatus = 'loading';
    this.cloudAIStatus = 'idle';

    const nativeKeywords = extractKeywordsNative(this.sourceText, 8);
    this.keywordSource = nativeKeywords.length > 0 ? 'native' : 'fallback';
    if (nativeKeywords.length > 0) {
      this.aiResult.keywords = this.normalizeList(nativeKeywords).slice(0, 8);
    }

    try {
      const extractRes = await httpRequest<AIExtractResponse>(`/notes/${this.noteId}/ai/extract`, 'POST');
      if (extractRes && extractRes.result) {
        const keywords = this.normalizeList(extractRes.result.keywords || []);
        const labels = this.normalizeList(extractRes.result.labels || []);
        const todos = this.normalizeList(extractRes.result.todos || []).slice(0, 8);
        this.aiResult = {
          keywords: this.aiResult.keywords.length > 0 ? this.aiResult.keywords : keywords,
          labels: labels,
          todos: todos,
          priority: extractRes.result.priority || 'normal',
          summary: this.aiResult.summary || ''
        };
        this.localAIStatus = (this.aiResult.keywords.length + labels.length + todos.length) > 0 ? 'success' : 'empty';
      } else {
        this.localAIStatus = 'empty';
      }
    } catch (e) {
      const error = e as Error;
      this.localAIStatus = 'failed';
      this.aiError = '端侧整理失败，请检查模型或本地服务状态。' + (error.message ? ` ${error.message}` : '');
    }

    this.cloudAIStatus = 'loading';
    try {
      const cloudRes = await httpRequest<AISummarizeResponse>(`/notes/${this.noteId}/ai/summarize`, 'POST');
      if (cloudRes && cloudRes.summary && cloudRes.summary.trim().length > 0) {
        this.aiResult.summary = this.normalizeSummary(cloudRes.summary);
        if (cloudRes.keywords && cloudRes.keywords.length > 0) {
          this.aiResult.keywords = this.normalizeList(cloudRes.keywords).slice(0, 8);
        }
        if (cloudRes.todos && cloudRes.todos.length > 0) {
          this.aiResult.todos = this.normalizeList(this.aiResult.todos.concat(cloudRes.todos)).slice(0, 10);
        }
        this.cloudAIStatus = 'success';
      } else {
        this.cloudAIStatus = 'empty';
        this.cloudNotice = '云端模型返回为空，可手动填写摘要，或稍后重新生成。';
      }
    } catch (e) {
      const error = e as Error;
      const msg = error.message || '';
      this.cloudAIStatus = msg.indexOf('timeout') >= 0 || msg.indexOf('Timeout') >= 0 || msg.indexOf('timed out') >= 0 ? 'timeout' : 'failed';
      this.cloudNotice = this.cloudAIStatus === 'timeout'
        ? '云端总结超时，端侧关键词和待办仍可使用。'
        : '云端总结不可用，已降级为端侧整理结果。';
    }

    this.isLoading = false;
  }

  async regenerate(): Promise<void> {
    await this.fetchData();
  }

  applySummary(): void {
    const summary = this.aiResult.summary.trim();
    if (!summary) {
      promptAction.showToast({ message: '摘要为空，不能应用' });
      return;
    }
    this.onApplySummary(summary);
    this.controller.close();
  }

  applyTodos(): void {
    const todos = this.normalizeList(this.aiResult.todos).filter((t: string) => t.trim().length > 0);
    if (todos.length === 0) {
      promptAction.showToast({ message: '暂无可创建的待办' });
      return;
    }
    this.onApplyTodos(todos);
    this.controller.close();
  }

  @Builder
  StatusBadge(text: string, bg: string, color: string): void {
    Text(text)
      .fontSize(11)
      .fontColor(color)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(bg)
      .borderRadius(10);
  }

  @Builder
  EmptyHint(text: string): void {
    Text(text)
      .fontSize(13)
      .fontColor('#A89982')
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .backgroundColor('#FBF8F3')
      .borderRadius(12);
  }

  build(): void {
    Column() {
      Row() {
        Column({ space: 5 }) {
          Text('AI 智能整理')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3F332D');
          Text('端侧即时抽取，云端深度总结，结果可编辑后写回')
            .fontSize(13)
            .fontColor('#9A8B7A');
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
          .onClick(() => this.controller.close());
      }
      .width('100%')
      .padding({ left: 24, right: 20, top: 22, bottom: 14 });

      if (this.isLoading) {
        Column({ space: 14 }) {
          LoadingProgress()
            .width(38)
            .height(38)
            .color('#9B7250');
          Text('正在整理笔记内容...')
            .fontSize(15)
            .fontColor('#8E7D6B');
          Text('端侧结果会优先返回，云端失败时不影响基础整理')
            .fontSize(12)
            .fontColor('#A89982');
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        Scroll() {
          Column({ space: 16 }) {
            if (this.aiError) {
              Text(this.aiError)
                .fontSize(13)
                .fontColor('#B7791F')
                .width('100%')
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor('#FFF8E8')
                .borderRadius(12);
            }

            Column({ space: 14 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('笔记整理')
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#4A3933');
                  Text('本地完成关键词、标签、待办和优先级抽取')
                    .fontSize(12)
                    .fontColor('#A89982');
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                this.StatusBadge(`${this.statusText(this.localAIStatus)}`, '#EEF5EA', '#5A7D45')
              }
              .width('100%')

              Row({ space: 8 }) {
                this.StatusBadge(this.priorityText(this.aiResult.priority), '#F3EBDD', '#8A5A32')
                this.StatusBadge(`关键词 ${this.aiResult.keywords.length}`, '#F0EDF8', '#6B5A9E')
                this.StatusBadge(`待办 ${this.aiResult.todos.length}`, '#EEF5EA', '#5A7D45')
                this.StatusBadge(`关键词来源 ${this.keywordSource === 'native' ? 'Native' : 'Fallback'}`, '#EFEFEF', '#666666')
              }
              .width('100%')

              Column({ space: 10 }) {
                Text('关键词')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4A3933')
                  .width('100%');

                if (this.aiResult.keywords.length === 0) {
                  this.EmptyHint('未识别到关键词，可继续编辑正文后重新生成。')
                } else {
                  Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                    ForEach(this.aiResult.keywords, (kw: string, idx: number) => {
                      Row({ space: 6 }) {
                        Text(kw)
                          .fontSize(14)
                          .fontColor('#6B5A42');
                        Text('×')
                          .fontSize(14)
                          .fontColor('#B8A996')
                          .onClick(() => {
                            this.aiResult.keywords = this.aiResult.keywords.filter((_: string, i: number) => i !== idx);
                          });
                      }
                      .padding({ left: 12, right: 10, top: 7, bottom: 7 })
                      .margin({ right: 8, bottom: 8 })
                      .backgroundColor('#F3EBDD')
                      .borderRadius(18);
                    }, (kw: string, i: number) => 'kw-' + i)
                  }
                  .width('100%')
                }
              }
              .width('100%')

              Column({ space: 10 }) {
                Text('建议标签')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4A3933')
                  .width('100%');

                if (this.aiResult.labels.length === 0) {
                  this.EmptyHint('暂无标签建议。')
                } else {
                  Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                    ForEach(this.aiResult.labels, (label: string, idx: number) => {
                      Row({ space: 6 }) {
                        Text(label)
                          .fontSize(14)
                          .fontColor('#5A6F43');
                        Text('×')
                          .fontSize(14)
                          .fontColor('#A8B998')
                          .onClick(() => {
                            this.aiResult.labels = this.aiResult.labels.filter((_: string, i: number) => i !== idx);
                          });
                      }
                      .padding({ left: 12, right: 10, top: 7, bottom: 7 })
                      .margin({ right: 8, bottom: 8 })
                      .backgroundColor('#EEF5EA')
                      .borderRadius(18);
                    }, (label: string, i: number) => 'label-' + i)
                  }
                  .width('100%')
                }
              }
              .width('100%')

              Column({ space: 10 }) {
                Text('识别待办')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4A3933')
                  .width('100%');

                if (this.aiResult.todos.length === 0) {
                  this.EmptyHint('未识别到明确待办，可手动添加。')
                }

                Column({ space: 9 }) {
                  ForEach(this.aiResult.todos, (todo: string, idx: number) => {
                    Row({ space: 10 }) {
                      Column()
                        .width(8)
                        .height(8)
                        .borderRadius(4)
                        .backgroundColor('#8BA078')
                        .flexShrink(0);

                      TextInput({ text: todo })
                        .fontSize(14)
                        .fontColor('#4A3933')
                        .backgroundColor(Color.Transparent)
                        .layoutWeight(1)
                        .onChange((v: string) => {
                          const newTodos = [...this.aiResult.todos];
                          newTodos[idx] = v;
                          this.aiResult.todos = newTodos;
                        });

                      Text('×')
                        .fontSize(16)
                        .fontColor('#B8A996')
                        .onClick(() => {
                          this.aiResult.todos = this.aiResult.todos.filter((_: string, i: number) => i !== idx);
                        });
                    }
                    .width('100%')
                    .padding({ left: 14, right: 12, top: 10, bottom: 10 })
                    .backgroundColor('#FBF8F3')
                    .borderRadius(13);
                  }, (todo: string, i: number) => 'todo-' + i)

                  Row({ space: 6 }) {
                    Text('+')
                      .fontSize(18)
                      .fontColor('#9B7250');
                    Text('添加待办')
                      .fontSize(14)
                      .fontColor('#9B7250');
                  }
                  .width('100%')
                  .padding({ top: 10, bottom: 10 })
                  .justifyContent(FlexAlign.Center)
                  .border({ width: 1, color: '#E8DCCA', style: BorderStyle.Dashed })
                  .borderRadius(13)
                  .onClick(() => {
                    this.aiResult.todos = [...this.aiResult.todos, ''];
                  });
                }
                .width('100%')
              }
              .width('100%')
            }
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(18)
            .shadow({ radius: 10, color: '#12000000', offsetY: 3 });

            Column({ space: 12 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('笔记总结')
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#4A3933');
                  Text('上传标题和正文生成摘要，适合长文本理解')
                    .fontSize(12)
                    .fontColor('#A89982');
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                this.StatusBadge(`${this.statusText(this.cloudAIStatus)}`, '#F0EDF8', '#6B5A9E')
              }
              .width('100%')

              if (this.cloudNotice) {
                Text(this.cloudNotice)
                  .fontSize(13)
                  .fontColor('#9A6A2F')
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 9, bottom: 9 })
                  .backgroundColor('#FFF8E8')
                  .borderRadius(12);
              }

              Row() {
                Text('摘要')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4A3933');
                Blank()
                Text(`${this.aiResult.summary.length}/300`)
                  .fontSize(12)
                  .fontColor('#A89982');
              }
              .width('100%')

              TextArea({ text: this.aiResult.summary, placeholder: '云端摘要为空时，可在这里手动填写...' })
                .fontSize(15)
                .fontColor('#4A3933')
                .backgroundColor('#FBF8F3')
                .borderRadius(14)
                .border({ width: 1, color: '#EEE3D6' })
                .padding(14)
                .height(122)
                .maxLength(300)
                .showCounter(false)
                .onChange((v: string) => {
                  this.aiResult.summary = v;
                });
            }
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(18)
            .shadow({ radius: 10, color: '#12000000', offsetY: 3 });
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 6, bottom: 10 });
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .layoutWeight(1);

        Row({ space: 10 }) {
          Button('重新生成')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#6F6254')
            .backgroundColor('#EFE8DD')
            .borderRadius(14)
            .height(42)
            .layoutWeight(1)
            .onClick(() => this.regenerate());

          Button('应用摘要')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#6F6254')
            .backgroundColor('#EFE8DD')
            .borderRadius(14)
            .height(42)
            .layoutWeight(1)
            .onClick(() => this.applySummary());

          Button('创建待办')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#6F5647')
            .borderRadius(14)
            .height(42)
            .layoutWeight(1)
            .onClick(() => this.applyTodos());
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 20 });
      }
    }
    .width('92%')
    .height('76%')
    .backgroundColor(this.themeBg)
    .borderRadius(24)
    .clip(true);
  }
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
  @StorageLink('themePrimary') themePrimary: string = '#6F7F4F';
  @StorageLink('themeText') themeText: string = '#3F382F';
  @StorageLink('themeSecondary') themeSecondary: string = '#B7A887';
  @StorageLink('themeAccent') themeAccent: string = '#D9A85F';
  @StorageLink('themeSoft') themeSoft: string = '#EEF3E5';
  @StorageLink('themeMascot') themeMascot: string = '🦙';

  private richController: RichEditorController = new RichEditorController();
  private plainContent: string = '';
  private aiDialogController: CustomDialogController | null = null;
  private importDialogController: CustomDialogController | null = null;
  private exportDialogController: CustomDialogController | null = null;

  private themeCoverResource(): Resource {
    if (this.view_type === 'meadow') return $r('app.media.note_bg_meadow');
    if (this.view_type === 'andes') return $r('app.media.note_bg_andes');
    if (this.view_type === 'wool') return $r('app.media.note_bg_wool');
    if (this.view_type === 'sunrise') return $r('app.media.note_bg_sunrise');
    if (this.view_type === 'ranch') return $r('app.media.note_bg_ranch');
    if (this.view_type === 'caravan') return $r('app.media.note_bg_caravan');
    if (this.themeMascot === '☁️') {
      return $r('app.media.note_bg_wool');
    }
    if (this.themeMascot === '⛰️' || this.themeMascot === '✦') {
      return $r('app.media.note_bg_andes');
    }
    return $r('app.media.note_bg_meadow');
  }

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
    const sizes: number[] = [28, 24, 20];
    const marks: string[] = ['# ', '## ', '### '];
    const fontSize = sizes[level - 1];
    const mark = marks[level - 1];
    this.richController.addTextSpan(`\n${mark}`, {
      style: { fontSize: fontSize, fontColor: '#4A3933', fontWeight: FontWeight.Bold }
    });
    this.richController.setTypingStyle({
      fontSize: fontSize,
      fontColor: '#4A3933',
      fontWeight: FontWeight.Bold
    });
  }

  insertBulletList(): void {
    this.richController.addTextSpan('\n- ', {
      style: { fontSize: 16, fontColor: '#4A3933' }
    });
    this.richController.setTypingStyle({ fontSize: 16, fontColor: '#4A3933', fontWeight: FontWeight.Normal });
  }

  insertChecklist(): void {
    this.richController.addTextSpan('\n- [ ] ', {
      style: { fontSize: 16, fontColor: '#4A3933' }
    });
    this.richController.setTypingStyle({ fontSize: 16, fontColor: '#4A3933', fontWeight: FontWeight.Normal });
  }

  insertCodeBlock(): void {
    this.richController.addTextSpan('\n```\ncode\n```\n', {
      style: { fontSize: 14, fontColor: '#2F6FA3' }
    });
    this.richController.setTypingStyle({ fontSize: 14, fontColor: '#2F6FA3', fontWeight: FontWeight.Normal });
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

  private getSuffix(name: string): string {
    const normalized = (name || '').trim().toLowerCase();
    const idx = normalized.lastIndexOf('.');
    if (idx < 0 || idx === normalized.length - 1) {
      return '';
    }
    return normalized.substring(idx + 1);
  }

  private toFormatBySuffix(suffix: string): 'md' | 'txt' | 'word' {
    if (suffix === 'md') {
      return 'md';
    }
    if (suffix === 'txt') {
      return 'txt';
    }
    return 'word';
  }

  async importFromFile(expectedFormat: 'md' | 'txt' | 'word'): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const result: string[] = await documentPicker.select({
        maxSelectNumber: 1,
        fileSuffixFilters: ['.md', '.txt', '.word', '.doc', '.docx']
      });
      if (!result || result.length === 0 || !result[0]) {
        promptAction.showToast({ message: '未选择文件' });
        return;
      }

      const fileUri: string = result[0];
      const normalizedUri = fileUri.toLowerCase();
      let suffix = '';
      for (let i = 0; i < IMPORT_ALLOWED_SUFFIXES.length; i++) {
        const currentSuffix = IMPORT_ALLOWED_SUFFIXES[i];
        if (normalizedUri.endsWith('.' + currentSuffix)) {
          suffix = currentSuffix;
          break;
        }
      }
      if (!suffix) {
        promptAction.showToast({ message: '文件后缀不支持，仅支持 md/txt/word/doc/docx' });
        return;
      }

      const fd = fs.openSync(fileUri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(fd.fd);
      if (!stat || stat.size <= 0) {
        fs.closeSync(fd.fd);
        promptAction.showToast({ message: '导入失败：文件为空' });
        return;
      }
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(fd.fd, buf);
      fs.closeSync(fd.fd);

      const decoder = new util.TextDecoder('utf-8', { ignoreBOM: true });
      const content = decoder.decodeWithStream(new Uint8Array(buf), { stream: false });
      if (!content || !content.trim()) {
        promptAction.showToast({ message: '导入失败：文件内容为空或不可读' });
        return;
      }

      const detectedFormat = this.toFormatBySuffix(suffix);
      if (expectedFormat !== detectedFormat) {
        promptAction.showToast({ message: `格式不匹配：当前选择 ${expectedFormat.toUpperCase()}，文件是 ${detectedFormat.toUpperCase()}` });
        return;
      }

      this.applyImportedContent({ format: detectedFormat, content: content });
      promptAction.showToast({ message: `已从文件导入 ${detectedFormat.toUpperCase()} 内容` });
    } catch (e) {
      const error = e as Error;
      console.error('文件导入失败', error.message);
      promptAction.showToast({ message: '导入失败，请检查文件权限或内容格式' });
    }
  }

  buildExportText(format: 'md' | 'txt' | 'word'): string {
    const title = this.title.trim();
    const summary = this.summary.trim();
    const body = this.extractPlainText().trim();
    if (format === 'md') {
      return `# ${title || '未命名笔记'}\n\n${summary ? `> ${summary}\n\n` : ''}${body}`;
    }
    if (format === 'word') {
      return `${title || '未命名笔记'}\n\n${summary ? `摘要：${summary}\n\n` : ''}${body}`;
    }
    return `${title || '未命名笔记'}\n\n${summary ? `摘要：${summary}\n\n` : ''}${body}`;
  }

  private sanitizeFileName(name: string): string {
    const base = (name || '未命名笔记').trim();
    const cleaned = base.replace(/[\\/:*?"<>|\s]+/g, '_');
    return cleaned.length > 0 ? cleaned : '未命名笔记';
  }

  private buildExportFilePath(format: 'md' | 'txt' | 'word'): string {
    const ext = format === 'md' ? 'md' : (format === 'txt' ? 'txt' : 'word');
    const fileName = `${this.sanitizeFileName(this.title)}_${Date.now()}.${ext}`;
    const ctx = getContext(this) as common.UIAbilityContext;
    return `${ctx.cacheDir}/${fileName}`;
  }

  async exportToDownload(result: ImportExportResult): Promise<void> {
    try {
      const output = (result.content || '').trim();
      if (!output) {
        promptAction.showToast({ message: '导出失败：内容为空' });
        return;
      }
      const targetPath = this.buildExportFilePath(result.format);
      const encoder = new util.TextEncoder();
      const bytes = encoder.encodeInto(output);
      const file = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, bytes.buffer as ArrayBuffer);
      fs.closeSync(file.fd);
      promptAction.showToast({ message: `已导出到应用缓存目录 ${targetPath}` });
    } catch (e) {
      const error = e as Error;
      console.error('导出文件失败', error.message);
      promptAction.showToast({ message: `导出失败：${error.message || '请检查应用存储状态'}` });
    }
  }

  applyImportedContent(result: ImportExportResult): void {
    const raw = result.content || '';
    if (!raw.trim()) {
      promptAction.showToast({ message: '导入内容为空' });
      return;
    }
    const lines = raw.split('\n');
    if (result.format === 'md' && lines.length > 0 && lines[0].startsWith('# ')) {
      this.title = lines[0].replace('# ', '').trim();
      this.summary = '';
      const body = lines.slice(1).join('\n').replace(/^\s+/, '');
      this.richController.deleteSpans();
      this.richController.addTextSpan(body, { style: { fontSize: 16, fontColor: '#4A3933' } });
      return;
    }
    if (!this.title.trim()) {
      this.title = lines[0].trim();
    }
    this.richController.deleteSpans();
    this.richController.addTextSpan(raw, { style: { fontSize: 16, fontColor: '#4A3933' } });
  }

  openImportDialog(): void {
    if (this.importDialogController) {
      this.importDialogController.close();
    }
    this.importDialogController = new CustomDialogController({
      builder: ImportDialog({
        controller: this.importDialogController ?? undefined,
        onConfirm: (result: ImportExportResult) => {
          this.applyImportedContent(result);
          promptAction.showToast({ message: `已导入 ${result.format.toUpperCase()} 内容` });
        },
        onPickFile: (format: 'md' | 'txt' | 'word') => {
          this.importFromFile(format);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.importDialogController.open();
  }

  openExportDialog(): void {
    if (this.exportDialogController) {
      this.exportDialogController.close();
    }
    this.exportDialogController = new CustomDialogController({
      builder: ExportDialog({
        controller: this.exportDialogController ?? undefined,
        defaultContent: this.buildExportText('md'),
        onConfirm: (result: ImportExportResult) => {
          this.exportToDownload(result);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.exportDialogController.open();
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

  @Builder
  BackgroundOption(key: string, label: string, res: Resource): void {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(res)
        .width(82)
        .height(58)
        .objectFit(ImageFit.Cover)
        .borderRadius(14)
        .opacity(this.view_type === key ? 1 : 0.72)

      Text(label)
        .fontSize(10)
        .fontColor('#FFFFFF')
        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .backgroundColor(this.view_type === key ? this.themePrimary : '#804A3933')
        .borderRadius(9)
        .margin({ left: 6, bottom: 6 })
    }
    .width(82)
    .height(58)
    .margin({ right: 10 })
    .border({
      width: this.view_type === key ? 2 : 0,
      color: this.themePrimary
    })
    .borderRadius(16)
    .onClick(() => {
      this.view_type = key;
    })
  }

  build(): void {
    Column() {
      // 顶部导航栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([this.themePrimary])
          .onClick(() => router.back());

        Blank();

        Text(this.noteId ? '编辑笔记' : '新灵感')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4A3933');

        Blank();

        if (this.isSaving) {
          LoadingProgress().width(24).height(24).color(this.themePrimary);
        } else {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(24)
            .fontColor([this.themePrimary])
            .onClick(() => this.validateAndSave());
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 10 });

      // 标题
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(this.themeCoverResource())
          .width('100%')
          .height(112)
          .objectFit(ImageFit.Cover)
          .borderRadius(24)
          .opacity(0.82)

        Row() {
          Column({ space: 4 }) {
            Text('灵感纸页')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeText)
            Text('记录、插图、模板与 AI 整理在这里汇合')
              .fontSize(11)
              .fontColor(this.themeText)
              .opacity(0.7)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Image($r('app.media.llama_mascot'))
            .width(58)
            .height(58)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 14 })
      }
      .width('90%')
      .height(112)
      .margin({ left: 20, right: 20, bottom: 12 })

      Column({ space: 8 }) {
        Text('笔记背景')
          .fontSize(12)
          .fontColor(this.themeSecondary)
          .width('100%')

        Scroll() {
          Row() {
            this.BackgroundOption('meadow', '草甸', $r('app.media.note_bg_meadow'))
            this.BackgroundOption('andes', '纸本', $r('app.media.note_bg_andes'))
            this.BackgroundOption('wool', '羊毛', $r('app.media.note_bg_wool'))
            this.BackgroundOption('sunrise', '晨光', $r('app.media.note_bg_sunrise'))
            this.BackgroundOption('ranch', '牧场', $r('app.media.note_bg_ranch'))
            this.BackgroundOption('caravan', '驼队', $r('app.media.note_bg_caravan'))
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(66)
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 10 })

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
          this.ToolBtn('•', false, () => this.insertBulletList(), false);
          this.ToolBtn('☑', false, () => this.insertChecklist(), false);
          this.ToolBtn('{ }', false, () => this.insertCodeBlock(), false);
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
          SymbolGlyph($r('sys.symbol.square_and_arrow_down'))
            .fontSize(20)
            .fontColor(['#705C53']);
          Text('导入')
            .fontSize(10)
            .fontColor('#A89982');
        }
        .layoutWeight(1)
        .padding({ top: 8, bottom: 8 })
        .onClick(() => this.openImportDialog());

        Column({ space: 4 }) {
          Text('⇪')
            .fontSize(20)
            .fontColor('#705C53');
          Text('导出')
            .fontSize(10)
            .fontColor('#A89982');
        }
        .layoutWeight(1)
        .padding({ top: 8, bottom: 8 })
        .onClick(() => this.openExportDialog());

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
        sourceText: this.extractPlainText(),
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
  private currentUploadTask: Object | null = null;

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
        data: [] as commonRequest.RequestData[]
      };

      this.currentUploadTask = await commonRequest.uploadFile(getContext(this), uploadConfig);

      (this.currentUploadTask as Record<string, (event: string, cb: Function) => void>).on('progress', (uploadedSize: number, totalSize: number) => {
        console.info(`上传中: ${uploadedSize}/${totalSize}`);
      });

      (this.currentUploadTask as Record<string, (event: string, cb: Function) => void>).on('headerReceive', (header: object) => {
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

      (this.currentUploadTask as Record<string, (event: string, cb: Function) => void>).on('complete', (taskStates: UploadTaskState[]) => {
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

      (this.currentUploadTask as Record<string, (event: string, cb: Function) => void>).on('fail', (taskStates: UploadTaskState[]) => {
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

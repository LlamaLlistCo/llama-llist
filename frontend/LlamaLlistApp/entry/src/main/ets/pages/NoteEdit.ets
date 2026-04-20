import { request as httpRequest} from '../common/network/httpClient';
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

// 定义上传配置接口
interface UploadFileConfig {
  url: string;
  header: Record<string, string>;
  method: string;
  files: Array<UploadFileItem>;
  data: Array<UploadDataItem>;
}

interface UploadFileItem {
  filename: string;
  name: string;
  uri: string;
  type: string;
}

interface UploadDataItem {
  name: string;
  value: string;
}

// ==================== 上传图片 ====================
@CustomDialog
struct ImageSourceDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} })
  onSelect: (type: 'album' | 'camera' | 'url') => void = () => {}

  build(): void {
    Column() {
      Text('添加图片')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .padding(20)

      List() {
        ListItem() {
          this.OptionItem($r('sys.symbol.picture'), '从相册选择', (): void => this.handleSelect('album'))
        }
        ListItem() {
          this.OptionItem($r('sys.symbol.camera'), '拍照', (): void => this.handleSelect('camera'))
        }
        ListItem() {
          this.OptionItem($r('sys.symbol.link'), '上传图片 URL', (): void => this.handleSelect('url'))
        }
      }
      .divider({ strokeWidth: 1, color: '#EFEBE9' })
      .padding({ bottom: 10 })
    }
    .backgroundColor(Color.White)
    .borderRadius(20)
    .width('90%')
  }

  @Builder
  OptionItem(icon: Resource, label: string, action: () => void): void {
    Row({ space: 15 }) {
      SymbolGlyph(icon).fontSize(24).fontColor(['#705C53'])
      Text(label).fontSize(16).fontColor('#4A3933')
    }
    .width('100%')
    .padding(16)
    .onClick(action)
  }

  handleSelect(type: 'album' | 'camera' | 'url'): void {
    this.onSelect(type)
    this.controller.close()
  }
}

// ==================== 模板弹窗 ====================
@CustomDialog
struct TemplateDialog {
  @Prop templates: NoteTemplate[] = []
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} })
  onSelect: (skeleton: string) => void = () => {}

  build() {
    Column() {
      Row() {
        Text('选择笔记模板')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4A3933')
        Blank()
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(20)
          .fontColor(['#A89982'])
          .onClick(() => this.controller.close())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 })

      Divider().color('#EFEBE9').strokeWidth(1)

      if (this.templates.length === 0) {
        Column({ space: 10 }) {
          Text('📋').fontSize(36)
          Text('暂无可用模板').fontSize(14).fontColor('#A89982')
        }
        .width('100%')
        .padding(40)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.templates, (item: NoteTemplate) => {
            ListItem() {
              Row({ space: 12 }) {
                Text(item.icon || '📝').fontSize(28)
                Column({ space: 4 }) {
                  Text(item.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#4A3933')
                  Text(item.category)
                    .fontSize(12)
                    .fontColor('#A89982')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16)
                  .fontColor(['#D2C4B0'])
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#F9F8F4')
              .borderRadius(12)
              .onClick(() => {
                this.onSelect(item.content_skeleton)
                this.controller.close()
              })
            }
          })
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 16 })
        .constraintSize({ maxHeight: 400 })
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .backgroundColor(Color.White)
    .borderRadius(20)
  }
}

// ==================== 颜色选择弹窗 ====================
@CustomDialog
struct PickerDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} })
  onSelect: (color: string) => void = () => {}

  private colors: string[] = [
    '#4A3933',
    '#C0392B',
    '#E67E22',
    '#D4AC0D',
    '#27AE60',
    '#2980B9',
    '#8E44AD',
    '#A89982',
  ]

  build() : void {
    Column({ space: 16 }) {
      Text('选择字体颜色')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3933')
        .padding({ top: 20, left: 20 })
        .width('100%')

      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(this.colors, (c: string) => {
          Column() {}
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor(c)
          .margin(8)
          .border({ width: 3, color: '#FFFFFF' })
          .shadow({ radius: 4, color: '#20000000', offsetY: 2 })
          .onClick(() => {
            this.onSelect(c)
            this.controller.close()
          })
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 24 })
    }
    .backgroundColor(Color.White)
    .borderRadius(20)
  }
}

@CustomDialog
struct UrlInputDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} })
  onConfirm: (url: string) => void = () => {}
  @State inputUrl: string = ''

  build(): void {
    Column({ space: 16 }) {
      Text('输入图片地址')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3933')
        .padding({ top: 20 })

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
        })

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(14)
          .fontColor('#A89982')
          .backgroundColor('#EFEBE9')
          .layoutWeight(1)
          .onClick((): void => {
            this.controller.close();
          })

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
          })
      }
      .width('100%')
      .padding({ top: 8, bottom: 20 })
    }
    .padding({ left: 20, right: 20 })
    .backgroundColor(Color.White)
    .borderRadius(20)
    .width('90%')
  }
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

  private richController: RichEditorController = new RichEditorController();
  private plainContent: string = '';

  aboutToAppear() : void {
    const params = router.getParams() as Record<string, Object>;
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
      return this.plainContent;
    }
  }

  validateAndSave() {
    if (!this.title.trim()) {
      promptAction.showToast({ message: '🦙：给灵感起个名字吧（标题不能为空）' });
      return;
    }
    this.saveNote();
  }

  // ── 格式操作 ──
  toggleBold() : void {
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

  insertHeading(level: number) : void  {
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

  insertNote() : void {
    this.richController.addTextSpan('\n⚠️ 注意：', {
      style: { fontSize: 15, fontColor: '#E67E22', fontWeight: FontWeight.Bold }
    });
    this.richController.setTypingStyle({
      fontSize: 15,
      fontColor: '#E67E22',
      fontWeight: FontWeight.Normal
    });
  }

  insertQuote() : void {
    this.richController.addTextSpan('\n❝  ', {
      style: { fontSize: 15, fontColor: '#A89982', fontStyle: FontStyle.Italic }
    });
    this.richController.setTypingStyle({
      fontSize: 15,
      fontColor: '#A89982',
      fontStyle: FontStyle.Italic
    });
  }

  insertTime() : void {
    const now = new Date();
    const pad = (n: number): string => n < 10 ? '0' + n : '' + n;
    const timeStr =
      `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}`;
    this.richController.addTextSpan(` 🕐 ${timeStr} `, {
      style: { fontSize: 13, fontColor: '#A89982' }
    });
    this.richController.setTypingStyle({
      fontSize: 16,
      fontColor: this.currentColor,
      fontWeight: this.isBold ? FontWeight.Bold : FontWeight.Normal
    });
  }

  insertDivider() : void {
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

  applyColor(color: string) {
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

  resetStyle() : void {
    this.isBold = false;
    this.currentColor = '#4A3933';
    this.richController.setTypingStyle({
      fontSize: 16,
      fontColor: '#4A3933',
      fontWeight: FontWeight.Normal,
      fontStyle: FontStyle.Normal
    });
  }

  openTemplateDialog() : void {
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

  openColorPicker() : void {
    let dController: CustomDialogController | undefined = undefined;
    dController = new CustomDialogController({
      builder: PickerDialog({
        controller: dController,
        onSelect: (color: string) : void => {
          this.applyColor(color);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 }
    });
    dController.open();
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

        Text(this.noteId ? '编辑笔记' : '新灵感')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4A3933')

        Blank()

        if (this.isSaving) {
          LoadingProgress().width(24).height(24).color('#705C53')
        } else {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(24)
            .fontColor(['#705C53'])
            .onClick(() => this.validateAndSave())
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 10 })

      // ── 标题 ──
      TextInput({ text: this.title, placeholder: '灵感标题...' })
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .placeholderColor('#D2C4B0')
        .fontColor('#4A3933')
        .backgroundColor(Color.Transparent)
        .width('100%')
        .padding({ left: 24, right: 24 })
        .onChange((v) => this.title = v)

      // ── 摘要 ──
      TextInput({ text: this.summary, placeholder: '添加一段简短的摘要（可选）' })
        .fontSize(14)
        .fontColor('#887A73')
        .placeholderColor('#D2C4B0')
        .backgroundColor(Color.Transparent)
        .width('100%')
        .padding({ left: 24, right: 24 })
        .onChange((v) => this.summary = v)

      Divider().color('#EFEBE9').strokeWidth(1).margin({ left: 24, right: 24, top: 8, bottom: 4 })

      // ── 标签行 ──
      Row({ space: 8 }) {
        Text('🏷️').fontSize(16)
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
                })
            }
          }, (tag: Tag) => tag.id.toString())
        }
        .listDirection(Axis.Horizontal)
        .height(35)
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        if (this.tagId !== null && this.tagNameById(this.tagId)) {
          Row({ space: 4 }) {
            Circle({ width: 6, height: 6 }).fill('#705C53')
            Text(this.tagNameById(this.tagId))
              .fontSize(11)
              .fontColor('#705C53')
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#EFEBE9')
          .borderRadius(10)
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24 })

      Divider().color('#EFEBE9').strokeWidth(1).margin({ left: 24, right: 24, top: 8, bottom: 0 })

      // ── RichEditor 正文 ──
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
        })

      // --- 在 RichEditor 下方，工具栏上方插入 ---
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
                    .backgroundColor('#F0F0F0') // 占位背景色，方便调试
                    .alt($r('sys.media.ohos_app_icon')) // 系统默认占位图
                    .onError(() => {
                      console.error('图片加载失败:', path);
                    })

                  // 删除按钮
                  SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
                    .fontSize(20)
                    .fontColor(['#C0392B'])
                    .onClick(() => {
                      // 使用 filter 触发状态更新
                      this.imagePaths = this.imagePaths.filter((_, i) => i !== index);
                    })
                }
                .width(100)
                .height(100)
              }, (path: string) => path) // 增加动态 Key 强制刷新
            }
            .padding({ left: 24, right: 24, top: 10, bottom: 10 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .height(120) // 固定高度，确保不会被 RichEditor 挤压消失
        }
      }
      .width('100%')
      .backgroundColor(this.imagePaths.length > 0 ? '#F9F8F4' : Color.Transparent)

      // ── 格式工具栏 ──
      Scroll() {
        Row({ space: 2 }) {
          this.ToolBtn('B', this.isBold, () => this.toggleBold(), true)
          this.ToolBtn('H1', false, () => this.insertHeading(1), false)
          this.ToolBtn('H2', false, () => this.insertHeading(2), false)
          this.ToolBtn('H3', false, () => this.insertHeading(3), false)
          this.ToolBtn('⚠️', false, () => this.insertNote(), false)
          this.ToolBtn('❝', false, () => this.insertQuote(), false)
          this.ToolBtn('🕐', false, () => this.insertTime(), false)
          this.ToolBtn('──', false, () => this.insertDivider(), false)
          this.ColorToolBtn()
          this.ToolBtn('Aa', false, () => this.resetStyle(), false)
          this.ToolBtn('📋', false, () => this.openTemplateDialog(), false)
        }
        .padding({ left: 12, right: 12 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(48)
      .backgroundColor('#FAFAF8')
      .border({ width: { top: 1 }, color: '#EFEBE9' })

      // ── 底部操作栏 ──
      Row() {
        Column({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.figure'))
            .fontSize(20)
            .fontColor(['#705C53'])
          Text('图片')
            .fontSize(10)
            .fontColor('#A89982')
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
        })

        Column({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(20)
            .fontColor(['#C0392B'])
          Text('清空')
            .fontSize(10)
            .fontColor('#C0392B')
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
          }).then((result) => {
            if (result.index === 1) {
              this.richController.deleteSpans();
            }
          });
        })

        Column({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle'))
            .fontSize(20)
            .fontColor(['#705C53'])
          Text('保存')
            .fontSize(10)
            .fontColor('#705C53')
            .fontWeight(FontWeight.Medium)
        }
        .layoutWeight(1)
        .padding({ top: 8, bottom: 8 })
        .onClick(() => this.validateAndSave())
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .border({ width: { top: 1 }, color: '#EFEBE9' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F9F8F4')
  }

  @Builder ToolBtn(label: string, active: boolean, action: () => void, isBoldStyle: boolean) {
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
      .onClick(action)
  }

  @Builder ColorToolBtn() {
    Column({ space: 2 }) {
      Text('A')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentColor)
      Column()
        .width(22)
        .height(3)
        .backgroundColor(this.currentColor)
        .borderRadius(2)
    }
    .width(40)
    .height(34)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#EFEBE9')
    .borderRadius(8)
    .margin(3)
    .onClick(() => this.openColorPicker())
  }

  // ── 数据方法 ──
  async fetchNote(id: number) {
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
      console.error('加载笔记失败', JSON.stringify(e));
      promptAction.showToast({ message: '加载笔记失败' });
    }
  }

  async fetchTags() {
    try {
      const data = await httpRequest<Tag[]>('/tags/', 'GET');
      this.tags = data ?? [];
    } catch (e) {
      console.error('加载标签失败', JSON.stringify(e));
    }
  }

  async fetchTemplates() {
    try {
      const data = await httpRequest<NoteTemplate[]>('/templates/', 'GET');
      this.templates = data ?? [];
    } catch (e) {
      console.error('获取模板失败');
    }
  }

  async saveNote() {
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
      promptAction.showToast({ message: '保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  // 1. 在类定义中声明一个私有变量（防止被回收）
  private currentUploadTask: commonRequest.UploadTask | null = null;

  async uploadToBackend(internalUri: string) {
    const SERVER_URL = "http://10.0.2.2:8000";

    try {
      const uploadConfig: commonRequest.UploadConfig = {
        url: `${SERVER_URL}/files/upload`,
        header: { 'Accept': '*/*' }, // 尽量精简 Header
        method: 'POST',
        files: [{
          filename: `upload_${Date.now()}.jpg`,
          name: 'file',
          uri: internalUri,
          type: 'image/jpeg'
        }],
        data: []
      };

      // 使用 await 获取任务实例
      this.currentUploadTask = await commonRequest.uploadFile(getContext(this), uploadConfig);

      // 新增：监听进度（用来确认任务是否真的动了）
      this.currentUploadTask.on('progress', (uploadedSize: number, totalSize: number) => {
        console.info(`上传中: ${uploadedSize}/${totalSize}`);
      });

      // 重要：监听 headerReceive 事件
      // 很多时候后端返回了 201 成功，但系统会触发 headerReceive 而不是 complete
      this.currentUploadTask.on('headerReceive', (headers: object) => {
        console.info('接收到响应头:', JSON.stringify(headers));
        // FastAPI 返回 201 时 complete 不触发，响应体在 headers 里的 body 字段
        try {
          const h = headers as Record<string, string>;
          const bodyStr = h['body'] ?? h['Body'] ?? '';
          if (bodyStr) {
            const response = JSON.parse(bodyStr) as UploadResponse;
            const purePath = response.url.startsWith('/') ? response.url : `/${response.url}`;
            const fullImageUrl = 'http://10.0.2.2:8000' + purePath;
            console.info('headerReceive 解析图片路径:', fullImageUrl);
            setTimeout(() => {
              this.imagePaths = [...this.imagePaths, fullImageUrl];
              promptAction.showToast({ message: '图片上传成功 ✓' });
            }, 0);
          }
        } catch (e) {
          console.error('headerReceive 解析失败:', JSON.stringify(e));
        }
      });

      this.currentUploadTask.on('complete', (taskStates: Array<commonRequest.TaskState>) => {
        console.info('任务完成状态:', JSON.stringify(taskStates));
        if (taskStates.length > 0 && taskStates[0].message) {
          try {
            const response = JSON.parse(taskStates[0].message) as UploadResponse;
            const purePath = response.url.startsWith('/') ? response.url : `/${response.url}`;
            const fullImageUrl = 'http://10.0.2.2:8000' + purePath;
            console.info('成功获取图片全路径:', fullImageUrl);
            // 只赋值一次，移除 setTimeout 的重复赋值
            this.imagePaths = [...this.imagePaths, fullImageUrl];
            promptAction.showToast({ message: '图片上传成功 ✓' });
          } catch (e) {
            console.error('解析失败:', JSON.stringify(e));
            promptAction.showToast({ message: '解析响应失败' });
          }
        }
      });

      this.currentUploadTask.on('fail', (taskStates: Array<commonRequest.TaskState>) => {
        console.error('上传彻底失败:', JSON.stringify(taskStates));
        promptAction.showToast({ message: '上传失败' });
      });

    } catch (err) {
      console.error('创建上传任务崩溃:', JSON.stringify(err));
    }
  }

  async prepareInternalFile(uri: string): Promise<string> {
    let context = getContext(this);
    let fileName = `upload_${Date.now()}.jpg`;
    let cacheDir = context.cacheDir; // 应用沙箱缓存目录
    let destPath = `${cacheDir}/${fileName}`;

    try {
      // 1. 打开原始文件
      let srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      // 2. 创建目标沙箱文件
      let destFile = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      // 3. 物理拷贝
      fs.copyFileSync(srcFile.fd, destFile.fd);
      // 4. 必须关闭文件句柄，否则文件会被占用
      fs.closeSync(srcFile.fd);
      fs.closeSync(destFile.fd);

      // 返回 request 模块支持的 internal 协议
      return `internal://cache/${fileName}`;
    } catch (e) {
      console.error('文件处理失败:', JSON.stringify(e));
      throw new Error('文件拷贝失败');
    }
  }

  // 1. 拍照
  async handleCamera() {
    let pickerProfile: cameraPicker.PickerProfile = { cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK };
    let result = await cameraPicker.pick(getContext(this), [cameraPicker.PickerMediaType.PHOTO], pickerProfile);
    if (result.resultUri) {
      let internalPath = await this.prepareInternalFile(result.resultUri);
      this.uploadToBackend(internalPath);
    }
  }

  // 2. 相册
  async handleAlbum() {
    let photoPicker = new photoAccessHelper.PhotoViewPicker();
    let result = await photoPicker.select({ MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, maxSelectNumber: 1 });
    if (result.photoUris.length > 0) {
      let internalPath = await this.prepareInternalFile(result.photoUris[0]);
      this.uploadToBackend(internalPath);
    }
  }

  // 3. URL 链接
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
      // 验证 URL 格式
      const urlPattern: RegExp = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/;
      if (!urlPattern.test(url)) {
        promptAction.showToast({ message: '图片地址格式不正确' });
        return;
      }

      // 保存 URL 到图片列表
      this.imagePaths = [...this.imagePaths, url];

      // 提示用户
      promptAction.showToast({ message: '图片 URL 已添加 ✓' });

      // 可选：在编辑器中添加一个占位文本
      // this.richController.addTextSpan('\n[图片: ' + url + ']\n', {
      //   style: {
      //     fontSize: 14,
      //     fontColor: '#A89982',
      //     fontStyle: FontStyle.Italic
      //   }
      // });
    } catch (err) {
      console.error('处理图片 URL 失败', JSON.stringify(err));
      promptAction.showToast({ message: '图片处理失败' });
    }
  }
}

import { request } from '../common/network/httpClient';
import { Todo, TodoPriority, TodoStatus } from '../models/Todo';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

interface TodoCreateRequest {
  title: string;
  deadline?: string;
  priority: TodoPriority;
  status?: TodoStatus;
}

interface DatePickerResult {
  year?: number;
  month?: number;
  day?: number;
}

interface PriorityConfig {
  label: string;
  desc: string;
  color: string;
  bg: string;
}

const PRIORITY_CONFIGS: Record<string, PriorityConfig> = {
  'important_urgent': { label: '重要且紧急', desc: '马上处理的关键任务', color: '#D32F2F', bg: '#FFEBEE' },
  'important_not_urgent': { label: '重要不紧急', desc: '需要规划和持续推进', color: '#D97B33', bg: '#FFF3E0' },
  'not_important_urgent': { label: '紧急不重要', desc: '有时间压力但可快速处理', color: '#2F6FA3', bg: '#E3F2FD' },
  'not_important_not_urgent': { label: '不重要不紧急', desc: '轻量收尾或灵感备忘', color: '#4E8A5B', bg: '#E8F5E9' }
};

@Entry
@Component
struct TodoBoard {
  @State titleInput: string = '';
  @State deadlineInput: string = '';
  @State selectedDeadline: string | null = null;
  @State selectedPriority: TodoPriority = 'important_urgent';
  @State isSubmitting: boolean = false;

  @StorageLink('themeBg') themeBg: string = '#F9F8F4';
  @StorageLink('themePrimary') themePrimary: string = '#705C53';
  @StorageLink('themeText') themeText: string = '#4A3933';
  @StorageLink('themeSecondary') themeSecondary: string = '#A89982';
  @StorageLink('themeAccent') themeAccent: string = '#D9A85F';
  @StorageLink('themeCard') themeCard: string = '#FFFFFF';
  @StorageLink('themeSoft') themeSoft: string = '#EEF3E5';

  build(): void {
    Column() {
      this.HeaderBar()

      Scroll() {
        Column({ space: 18 }) {
          this.HeroCard()
          this.TitleInputCard()
          this.DeadlineCard()
          this.PriorityPicker()
          this.PreviewCard()
        }
        .padding({ left: 20, right: 20, top: 10, bottom: 18 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      this.SubmitBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBg)
  }

  @Builder HeaderBar(): void {
    Row() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([this.themePrimary])
      }
      .width(40)
      .height(40)
      .backgroundColor(this.themeSoft)
      .onClick(() => router.back())

      Blank()

      Text('新增待办')
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeText)

      Blank()

      Text('LL')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themePrimary)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.themeSoft)
        .borderRadius(20)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 8 })
  }

  @Builder HeroCard(): void {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image($r('app.media.note_bg_ranch'))
        .width('100%')
        .height(160)
        .objectFit(ImageFit.Cover)
        .opacity(0.76)

      Row() {
        Column({ space: 6 }) {
          Text('Llama Peak')
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
            .fontColor(this.themeText)
          Text('把下一步写清楚，任务就已经开始前进。')
            .fontSize(12)
            .fontColor(this.themeText)
            .opacity(0.72)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.llama_mascot'))
          .width(68)
          .height(68)
          .objectFit(ImageFit.Contain)
      }
      .width('100%')
      .padding({ left: 18, right: 18, bottom: 20 })
    }
    .width('100%')
    .height(158)
    .borderRadius(24)
    .clip(true)
    .backgroundColor(this.themeCard)
    .shadow({ radius: 12, color: '#124A3933', offsetY: 5 })
  }

  @Builder SectionTitle(title: string, hint: string): void {
    Row() {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeText)
        Text(hint)
          .fontSize(11)
          .fontColor(this.themeSecondary)
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
    }
    .width('100%')
  }

  @Builder TitleInputCard(): void {
    Column({ space: 12 }) {
      this.SectionTitle('任务标题', '建议写成一个可以直接执行的动作')
      TextInput({
        placeholder: '例如：整理课堂笔记并生成行动项',
        text: this.titleInput
      })
        .onChange((v: string) => this.titleInput = v)
        .fontSize(16)
        .fontColor(this.themeText)
        .placeholderColor(this.themeSecondary)
        .backgroundColor(this.themeSoft)
        .borderRadius(16)
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .height(54)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.themeCard)
    .borderRadius(22)
    .shadow({ radius: 8, color: '#084A3933', offsetY: 3 })
  }

  @Builder DeadlineCard(): void {
    Column({ space: 12 }) {
      this.SectionTitle('截止日期', '可选；过期任务会自动进入已延期')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([this.themePrimary])

        Text(this.deadlineInput || '点击选择日期')
          .fontSize(15)
          .fontColor(this.deadlineInput ? this.themeText : this.themeSecondary)
          .layoutWeight(1)

        if (this.deadlineInput) {
          Text('清除')
            .fontSize(12)
            .fontColor(this.themePrimary)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(this.themeSoft)
            .borderRadius(12)
            .onClick(() => {
              this.deadlineInput = '';
              this.selectedDeadline = null;
            })
        }
      }
      .width('100%')
      .height(54)
      .padding({ left: 14, right: 12 })
      .backgroundColor(this.themeSoft)
      .borderRadius(16)
      .onClick(() => this.openDatePicker())
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.themeCard)
    .borderRadius(22)
    .shadow({ radius: 8, color: '#084A3933', offsetY: 3 })
  }

  @Builder PriorityPicker(): void {
    Column({ space: 12 }) {
      this.SectionTitle('重要紧急程度', '沿用任务页的四个彩色圆点逻辑')

      Column({ space: 10 }) {
        Row({ space: 10 }) {
          this.PriorityOption('important_urgent')
          this.PriorityOption('important_not_urgent')
        }
        Row({ space: 10 }) {
          this.PriorityOption('not_important_urgent')
          this.PriorityOption('not_important_not_urgent')
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.themeCard)
    .borderRadius(22)
    .shadow({ radius: 8, color: '#084A3933', offsetY: 3 })
  }

  @Builder PriorityOption(priority: TodoPriority): void {
    Column({ space: 8 }) {
      Row() {
        Circle({ width: 12, height: 12 })
          .fill(PRIORITY_CONFIGS[priority].color)
        Blank()
        if (this.selectedPriority === priority) {
          Text('✓')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIORITY_CONFIGS[priority].color)
        }
      }
      .width('100%')

      Text(PRIORITY_CONFIGS[priority].label)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeText)
        .maxLines(1)

      Text(PRIORITY_CONFIGS[priority].desc)
        .fontSize(11)
        .fontColor(this.themeSecondary)
        .lineHeight(16)
        .maxLines(2)
    }
    .layoutWeight(1)
    .height(96)
    .padding({ left: 13, right: 13, top: 12, bottom: 12 })
    .backgroundColor(this.selectedPriority === priority ? PRIORITY_CONFIGS[priority].bg : this.themeSoft)
    .borderRadius(18)
    .border({
      width: this.selectedPriority === priority ? 1.4 : 0,
      color: this.selectedPriority === priority ? PRIORITY_CONFIGS[priority].color : '#00FFFFFF'
    })
    .onClick(() => this.selectedPriority = priority)
  }

  @Builder PreviewCard(): void {
    Row({ space: 12 }) {
      Column()
        .width(18)
        .height(18)
        .borderRadius(9)
        .border({ width: 1.4, color: this.themeSecondary })

      Column({ space: 7 }) {
        Text(this.titleInput.trim() || '任务预览会显示在这里')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.titleInput.trim() ? this.themeText : this.themeSecondary)
          .maxLines(2)

        Row({ space: 8 }) {
          Text(PRIORITY_CONFIGS[this.selectedPriority].label)
            .fontSize(11)
            .fontColor(PRIORITY_CONFIGS[this.selectedPriority].color)
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor(PRIORITY_CONFIGS[this.selectedPriority].bg)
            .borderRadius(12)

          if (this.deadlineInput) {
            Text(this.deadlineInput)
              .fontSize(11)
              .fontColor(this.themeSecondary)
          }
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#DFFFFFFF')
    .borderRadius(20)
    .shadow({ radius: 8, color: '#084A3933', offsetY: 3 })
  }

  @Builder SubmitBar(): void {
    Button(this.isSubmitting ? '正在创建...' : '创建待办')
      .width('100%')
      .height(54)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .backgroundColor(this.titleInput.trim().length > 0 ? this.themePrimary : this.themeSecondary)
      .borderRadius(18)
      .margin({ left: 20, right: 20, bottom: 24, top: 6 })
      .enabled(!this.isSubmitting && this.titleInput.trim().length > 0)
      .onClick(() => this.createTodo())
  }

  private openDatePicker(): void {
    DatePickerDialog.show({
      start: new Date('2024-01-01'),
      end: new Date('2030-12-31'),
      onAccept: (value: DatePickerResult) => {
        if (value.year !== undefined && value.month !== undefined && value.day !== undefined) {
          const m = (value.month + 1).toString().padStart(2, '0');
          const d = value.day.toString().padStart(2, '0');
          this.deadlineInput = `${value.year}-${m}-${d}`;
          this.selectedDeadline = this.deadlineInput;
        }
      }
    });
  }

  async createTodo(): Promise<void> {
    const title = this.titleInput.trim();
    if (!title) {
      promptAction.showToast({ message: '待办标题不能为空' });
      return;
    }

    this.isSubmitting = true;
    try {
      let initialState: TodoStatus = 'pending';
      if (this.selectedDeadline) {
        const now = new Date().getTime();
        const deadlineTime = new Date(this.selectedDeadline).getTime();
        if (deadlineTime < now) {
          initialState = 'delayed';
        }
      }

      const payload: TodoCreateRequest = {
        title: title,
        deadline: this.selectedDeadline ?? undefined,
        priority: this.selectedPriority,
        status: initialState
      };

      await request<Todo>('/todos/', 'POST', payload);
      promptAction.showToast({ message: '待办已添加' });
      router.back();
    } catch (e) {
      const error = e as Error;
      console.error('添加待办失败', error.message);
      promptAction.showToast({ message: '添加失败，请重试' });
    } finally {
      this.isSubmitting = false;
    }
  }
}

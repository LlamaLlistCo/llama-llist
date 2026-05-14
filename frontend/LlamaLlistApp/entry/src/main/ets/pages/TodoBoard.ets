import { request } from '../common/network/httpClient';
import { Todo, TodoStatus } from '../models/Todo';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

interface TodoCreateRequest {
  title: string;
  deadline?: string;
  priority: string;
  status?: TodoStatus;
}

interface DatePickerResult {
  year?: number;
  month?: number;
  day?: number;
}

interface PriorityConfig {
  label: string;
  color: string;
  bg: string;
}

const priorityConfigs: Record<string, PriorityConfig> = {
  'important_urgent': { label: '重要紧急', color: '#D32F2F', bg: '#FFEBEE' },
  'important_not_urgent': { label: '重要不紧急', color: '#F57C00', bg: '#FFF3E0' },
  'not_important_urgent': { label: '不重要紧急', color: '#1976D2', bg: '#E3F2FD' },
  'not_important_not_urgent': { label: '不重要不紧急', color: '#388E3C', bg: '#E8F5E9' },
};

@Entry
@Component
struct TodoBoard {
  @State titleInput: string = '';
  @State deadlineInput: string = '';
  @State selectedDeadline: string | null = null;
  @State selectedPriority: string = 'important_urgent';
  @State isSubmitting: boolean = false;
  @StorageLink('themeBg') themeBg: string = '#F9F8F4';

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor(['#705C53'])
          .onClick(() => router.back())

        Blank()

        Text('新增待办')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4A3933')

        Blank()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 16 })

      // 上方输入区域（标题 + 日期 + 优先级）
      Scroll() {
        Column({ space: 24 }) {
          // 1. 标题
          Column({ space: 8 }) {
            Text('任务标题').fontSize(14).fontColor('#A89982')
            TextInput({
              placeholder: '请输入待办标题（必填）',
              text: this.titleInput
            })
              .onChange((v: string) => this.titleInput = v)
              .fontSize(16)
              .fontColor('#4A3933')
              .placeholderColor('#D2C4B0')
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .height(52)
          }

          // 2. 截止日期
          Column({ space: 8 }) {
            Text('截止日期（可选）').fontSize(14).fontColor('#A89982')
            Row() {
              Text(this.deadlineInput || '点击选择日期')
                .fontSize(16)
                .fontColor(this.deadlineInput ? '#4A3933' : '#D2C4B0')
                .layoutWeight(1)
                .height(52)
                .padding({ left: 16, right: 16 })
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .onClick(() => {
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
                })
            }
          }

          // 3. 优先级选择
          Column({ space: 8 }) {
            Text('重要紧急程度').fontSize(14).fontColor('#A89982')
            List({ space: 10 }) {
              ForEach(['important_urgent', 'important_not_urgent', 'not_important_urgent', 'not_important_not_urgent'], (p: string) => {
                ListItem() {
                  Text(this.getPriorityLabel(p))
                    .fontSize(15)
                    .fontColor(this.selectedPriority === p ? '#FFF' : '#705C53')
                    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
                    .backgroundColor(this.selectedPriority === p ? '#705C53' : '#EFEBE9')
                    .borderRadius(12)
                    .onClick(() => this.selectedPriority = p)
                }
              })
            }
            .listDirection(Axis.Horizontal)
            .scrollBar(BarState.Off)
          }
        }
        .padding({ left: 20, right: 20, top: 10 })
      }
      .align(Alignment.Top)
      .layoutWeight(1)

      // 下方留空（以后扩展其他功能）
      // Blank()

      // 添加按钮（固定在底部）
      Button('添加待办')
        .width('100%')
        .height(52)
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor('#705C53')
        .borderRadius(12)
        .margin({ left: 20, right: 20, bottom: 30 })
        .enabled(!this.isSubmitting && this.titleInput.trim().length > 0)
        .onClick(() => this.createTodo())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBg)
  }

  private getPriorityLabel(p: string): string {
    const map: Record<string, string> = {
      'important_urgent': '重要紧急',
      'important_not_urgent': '重要不紧急',
      'not_important_urgent': '不重要紧急',
      'not_important_not_urgent': '不重要不紧急'
    };
    return map[p] || p;
  }

  async createTodo() {
    const title = this.titleInput.trim();
    if (!title) {
      promptAction.showToast({ message: '🦙 待办标题不能为空' });
      return;
    }

    this.isSubmitting = true;
    try {
      let initialState: TodoStatus = 'pending';
      if (this.selectedDeadline) {
        const now = new Date().getTime();
        const deadlineTime = new Date(this.selectedDeadline).getTime();
        // 如果选择的截止日期（天）早于今天，直接设为延期
        // 注意：DatePickerDialog 返回的是日期零点，这里做简单判定
        if (deadlineTime < now) {
          initialState = 'delayed';
        }
      }

      const payload: Record<string, string | undefined> = {
        'title': title,
        'deadline': this.selectedDeadline ?? undefined,
        'priority': this.selectedPriority,
        'status': initialState as string
      };

      await request<Todo>('/todos/', 'POST', payload);
      promptAction.showToast({ message: '待办已添加 ✓' });
      router.back();   // 返回首页
    } catch (e) {
      promptAction.showToast({ message: '添加失败，请重试' });
    } finally {
      this.isSubmitting = false;
    }
  }
}
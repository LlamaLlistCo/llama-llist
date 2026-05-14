import { request } from '../common/network/httpClient';
import { Note } from '../models/Note';
import { Tag } from '../models/Tag';
import { Todo, TodoStatus, TodoPriority } from '../models/Todo';
import { THEMES, ThemeConfig } from '../common/constants/Theme';
import { appTheme } from '../common/constants/ThemeManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

interface TodoCreateRequest {
  title: string;
  deadline?: string;
}

interface TodoUpdateRequest {
  status: TodoStatus;
  priority?: TodoPriority;
}

interface StatusItem {
  s: TodoStatus;
  label: string;
}

interface StatusConfig {
  label: string;
  color: string;
  bg: string;
}

interface DialogResult {
  index: number;
}

interface AISettingsResponse {
  provider_url: string;
}

interface AISettingsPayload {
  provider_url: string;
  api_key?: string;
}

@Entry
@Component
struct Index {
  @State notes: Note[] = [];
  @State tags: Tag[] = [];
  @State currentIndex: number = 0;
  private controller: TabsController = new TabsController();

  @State selectedTagId: number | null = null;
  @State selectedCategory: number = 0;
  @State aiProviderUrl: string = '';
  @State aiApiKeyInput: string = '';
  @State settingsDialogController: CustomDialogController | null = null;
  @State themeDialogController: CustomDialogController | null = null;
  @State currentTheme: ThemeConfig = THEMES[0];
  @StorageLink('themeBg') themeBg: string = '#F9F8F4';
  @StorageLink('themePrimary') themePrimary: string = '#705C53';
  @StorageLink('themeText') themeText: string = '#4A3933';
  @StorageLink('themeSecondary') themeSecondary: string = '#A89982';

  @State todos: Todo[] = [];
  @State todoTitleInput: string = '';
  @State todoDeadlineInput: string = '';
  @State statusFilter: TodoStatus | 'all' = 'all';
  @State priorityFilter: string | 'all' = 'all';
  @State isSubmittingTodo: boolean = false;
  @State showTodoInput: boolean = false;

  onPageShow(): void {
    this.fetchNotes();
    if (this.currentIndex === 1) {
      this.fetchTodos();
    }
    this.fetchTags();
    this.checkAndUpdateExpiredTodos();
  }

  aboutToAppear(): void {
    this.fetchTags();
    this.fetchNotes();
    this.fetchTodos();
    this.checkAndUpdateExpiredTodos();
    this.loadCurrentTheme();
  }

  async fetchNotes(): Promise<void> {
    try {
      const data = await request<Note[]>('/notes/', 'GET');
      this.notes = data ?? [];
    } catch (e) {
      const error = e as Error;
      console.error('加载笔记失败', error.message);
    }
  }

  async deleteNote(id: number): Promise<void> {
    try {
      await request<object>(`/notes/${id}`, 'DELETE');
      promptAction.showToast({ message: '笔记已删除' });
      await this.fetchNotes();
    } catch (e) {
      const error = e as Error;
      console.error('删除笔记失败', error.message);
      promptAction.showToast({ message: '删除失败' });
    }
  }

  async fetchTags(): Promise<void> {
    try {
      const data = await request<Tag[]>('/tags/', 'GET');
      this.tags = data ?? [];
    } catch (e) {
      const error = e as Error;
      console.error('加载标签失败', error.message);
    }
  }

  tagNameById(tagId?: number): string {
    if (typeof tagId !== 'number') return '';
    const found = this.tags.find(t => t.id === tagId);
    return found ? found.name : '';
  }

  async fetchNotesByTag(tagId: number): Promise<void> {
    try {
      const data = await request<Note[]>(`/notes/?tag_id=${tagId}`, 'GET');
      this.notes = data ?? [];
    } catch (e) {
      const error = e as Error;
      console.error('获取分类笔记失败', error.message);
      promptAction.showToast({ message: '获取分类笔记失败' });
    }
  }

  async fetchTodos(): Promise<void> {
    try {
      const params: string[] = [];
      if (this.statusFilter !== 'all') params.push(`status=${this.statusFilter}`);
      if (this.priorityFilter !== 'all') params.push(`priority=${this.priorityFilter}`);

      const qs = params.length > 0 ? '?' + params.join('&') : '';
      const data = await request<Todo[]>(`/todos/${qs}`, 'GET');

      let rawList = data ?? [];
      this.todos = rawList.sort((a: Todo, b: Todo) => {
        if (a.status === 'completed' && b.status !== 'completed') return 1;
        if (a.status !== 'completed' && b.status === 'completed') return -1;

        if (!a.deadline && !b.deadline) return 0;
        if (!a.deadline) return 1;
        if (!b.deadline) return -1;

        const timeA = new Date(a.deadline).getTime();
        const timeB = new Date(b.deadline).getTime();
        return timeA - timeB;
      });
    } catch (e) {
      const error = e as Error;
      console.error('加载待办失败', error.message);
    }
  }

  async createTodo(): Promise<void> {
    const title = this.todoTitleInput.trim();
    if (!title) {
      promptAction.showToast({ message: '🦙 待办标题不能为空' });
      return;
    }
    let deadlineIso: string | undefined = undefined;
    const d = this.todoDeadlineInput.trim();
    if (d) {
      const parsed = new Date(d);
      if (!Number.isNaN(parsed.getTime())) {
        deadlineIso = parsed.toISOString();
      } else {
        promptAction.showToast({ message: '截止日期格式不正确' });
        return;
      }
    }
    this.isSubmittingTodo = true;
    try {
      const payload: TodoCreateRequest = { title, deadline: deadlineIso };
      await request<Todo>('/todos/', 'POST', payload);
      this.todoTitleInput = '';
      this.todoDeadlineInput = '';
      this.showTodoInput = false;
      await this.fetchTodos();
      promptAction.showToast({ message: '任务已添加 ✓' });
    } catch (e) {
      const error = e as Error;
      console.error('添加待办失败', error.message);
      promptAction.showToast({ message: '添加失败' });
    } finally {
      this.isSubmittingTodo = false;
    }
  }

  async setTodoStatus(id: number, status: TodoStatus): Promise<void> {
    try {
      const payload: TodoUpdateRequest = { status };
      await request<Todo>(`/todos/${id}`, 'PUT', payload);
      await this.fetchTodos();
    } catch (e) {
      const error = e as Error;
      console.error('更新状态失败', error.message);
      promptAction.showToast({ message: '更新状态失败' });
    }
  }

  async setTodoPriority(id: number, priority: TodoPriority): Promise<void> {
    // 不使用展开运算符，手动构造新对象
    const nextTodos = this.todos.map((t: Todo): Todo => {
      if (t.id === id) {
        return {
          id: t.id,
          title: t.title,
          status: t.status,
          priority: priority,
          deadline: t.deadline,
          note_id: t.note_id
        };
      }
      return t;
    });
    this.todos = nextTodos;

    try {
      const payload: TodoUpdateRequest = { status: this.getCurrentStatusById(id), priority };
      await request<Todo>(`/todos/${id}`, 'PUT', payload);
      await this.fetchTodos();
      promptAction.showToast({ message: '优先级已更新' });
    } catch (e) {
      const error = e as Error;
      console.error('更新优先级失败', error.message);
      promptAction.showToast({ message: '更新优先级失败' });
      await this.fetchTodos();
    }
  }

  private getCurrentStatusById(id: number): TodoStatus {
    const todo = this.todos.find(t => t.id === id);
    return todo ? todo.status : 'pending';
  }

  async deleteTodo(id: number): Promise<void> {
    try {
      await request<object>(`/todos/${id}`, 'DELETE');
      await this.fetchTodos();
      promptAction.showToast({ message: '已删除' });
    } catch (e) {
      const error = e as Error;
      console.error('删除待办失败', error.message);
      promptAction.showToast({ message: '删除失败' });
    }
  }

  async checkAndUpdateExpiredTodos(): Promise<void> {
    try {
      const now = new Date().getTime();
      const updatePromises: Promise<Todo | null>[] = [];

      for (const todo of this.todos) {
        if (todo.deadline && todo.status === 'pending') {
          const deadlineTime = new Date(todo.deadline).getTime();
          if (deadlineTime < now) {
            const updatePayload: TodoUpdateRequest = { status: 'delayed' };
            updatePromises.push(
              request<Todo>(`/todos/${todo.id}`, 'PUT', updatePayload)
            );
          }
        }
      }

      if (updatePromises.length > 0) {
        await Promise.all(updatePromises);
        promptAction.showToast({ message: `已自动更新 ${updatePromises.length} 个延期任务` });
      }
      await this.fetchTodos();
    } catch (e) {
      const error = e as Error;
      console.error('自动更新延期任务失败', error.message);
    }
  }

  loadCurrentTheme(): void {
    this.currentTheme = appTheme.getTheme();
  }

  async switchTheme(themeId: number): Promise<void> {
    appTheme.setTheme(themeId);
    this.currentTheme = appTheme.getTheme();
    try {
      await request<object>(`/settings/theme/${themeId}`, 'POST');
      promptAction.showToast({ message: '主题已切换' });
    } catch (e) {
      const error = e as Error;
      console.error('切换主题失败', error.message);
    }
  }

  todoStatusConfig(status: TodoStatus): StatusConfig {
    if (status === 'completed') {
      return { label: '已完成', color: '#2E7D32', bg: '#E8F5E9' };
    } else if (status === 'delayed') {
      return { label: '已延期', color: '#C0392B', bg: '#FDECEC' };
    } else {
      return { label: '待处理', color: '#705C53', bg: '#EFEBE9' };
    }
  }

  getFallbackStatus(deadline?: string): TodoStatus {
    if (!deadline) return 'pending';
    const now = new Date().getTime();
    const isOverdue = new Date(deadline).getTime() < now;
    return isOverdue ? 'delayed' : 'pending';
  }

  getFallbackLabel(deadline?: string): string {
    return this.getFallbackStatus(deadline) === 'delayed' ? '已延期' : '待处理';
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

  private getPriorityColor(p: string): string {
    const map: Record<string, string> = {
      'important_urgent': '#D32F2F',
      'important_not_urgent': '#F57C00',
      'not_important_urgent': '#1976D2',
      'not_important_not_urgent': '#388E3C'
    };
    return map[p] || '#705C53';
  }

  private getPriorityBg(p: string): string {
    const map: Record<string, string> = {
      'important_urgent': '#FFEBEE',
      'important_not_urgent': '#FFF3E0',
      'not_important_urgent': '#E3F2FD',
      'not_important_not_urgent': '#E8F5E9'
    };
    return map[p] || '#EFEBE9';
  }

  build(): void {
    Column() {
      Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
        TabContent() {
          this.NotesTab()
        }.tabBar(this.TabBuilder('草原', 0, 'sys.symbol.house'))

        TabContent() {
          this.PeakSection()
        }.tabBar(this.TabBuilder('任务', 1, 'sys.symbol.checkmark_circle'))

        TabContent() {
          this.PackSection()
        }.tabBar(this.TabBuilder('行囊', 2, 'sys.symbol.person_crop_circle'))
      }
      .onChange((index: number) => {
        this.currentIndex = index;
        if (index === 1) {
          this.fetchTodos();
        }
      })
      .barHeight(60)
      .backgroundColor('#FFFFFF')
      .barMode(BarMode.Fixed)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBg)
  }

  @Builder TabBuilder(title: string, index: number, icon: string): void {
    Column() {
      SymbolGlyph($r(icon))
        .fontSize(22)
        .fontColor([this.currentIndex === index ? '#705C53' : '#D2C4B0'])
      Text(title)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentIndex === index ? '#705C53' : '#D2C4B0')
        .margin({ top: 4 })
    }
    .width('100%')
  }

  @Builder MeadowHeader(): void {
    Row() {
      Column() {
        Text('Llama Meadow')
          .fontSize(28)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#4A3933')
          .letterSpacing(1)
        Text('发现并记录你的灵感碎片')
          .fontSize(12)
          .fontColor('#D2C4B0')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(22)
        .fontColor(['#705C53'])
        .onClick(() => router.pushUrl({ url: 'pages/SearchPage' }))
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 30, bottom: 15 })
  }

  @Builder
  NotesTab(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.MeadowHeader()

        Scroll() {
          Row({ space: 12 }) {
            Text('全部')
              .fontSize(14)
              .fontWeight(this.selectedTagId === null ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.selectedTagId === null ? '#705C53' : '#A89982')
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .backgroundColor(this.selectedTagId === null ? '#EFEBE9' : Color.Transparent)
              .borderRadius(20)
              .onClick(() => {
                this.selectedTagId = null;
                this.fetchNotes();
              })

            ForEach(this.tags, (tag: Tag) => {
              Text(tag.name)
                .fontSize(14)
                .fontWeight(this.selectedTagId === tag.id ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.selectedTagId === tag.id ? '#705C53' : '#A89982')
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .backgroundColor(this.selectedTagId === tag.id ? '#EFEBE9' : Color.Transparent)
                .borderRadius(20)
                .onClick(() => {
                  this.selectedTagId = tag.id;
                  this.fetchNotesByTag(tag.id);
                })
            }, (tag: Tag) => tag.id.toString())

            Text('＋')
              .fontSize(20)
              .fontColor('#A89982')
              .padding({ left: 12, right: 12 })
              .onClick(() => router.pushUrl({ url: 'pages/TagManage' }))
          }
          .padding({ left: 24, right: 24 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .margin({ top: 10, bottom: 10 })

        if (this.notes.length === 0) {
          this.EmptyState()
        } else {
          List({ space: 16 }) {
            ForEach(this.notes, (note: Note) => {
              ListItem() {
                this.NoteCard(note)
              }
              .swipeAction({
                end: {
                  builder: () => { this.noteSwipeBuilder(note.id) },
                  onAction: () => {},
                  actionAreaDistance: 80,
                },
                edgeEffect: SwipeEdgeEffect.Spring
              })
              .onClick(() => {
                router.pushUrl({ url: 'pages/NoteEdit', params: { id: note.id } });
              })
            }, (item: Note) => item.id.toString())
          }
          .padding({ left: 20, right: 20, bottom: 0 })
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')

      Button({ type: ButtonType.Circle }) {
        Text('+').fontSize(28).fontColor('#FFF')
      }
      .width(52)
      .height(52)
      .backgroundColor('#705C53')
      .shadow({ radius: 12, color: '#204A3933', offsetY: 4 })
      .margin({ right: 20, bottom: 20 })
      .onClick(() => router.pushUrl({ url: 'pages/NoteEdit' }))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBg)
  }

  @Builder
  noteSwipeBuilder(id: number): void {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(20)
          .fontColor(['#FFFFFF'])
      }
      .width(60)
      .height(60)
      .backgroundColor('#C0392B')
      .type(ButtonType.Circle)
      .margin({ left: 15, right: 15 })
      .onClick(() => {
        this.deleteNote(id);
      })
    }
    .justifyContent(FlexAlign.Center)
    .height('100%')
  }

  @Builder PeakSection(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Row() {
          Column() {
            Text('Llama Peak')
              .fontSize(28)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#4A3933')
              .letterSpacing(1)
            Text('逐一攀越你的每一个目标')
              .fontSize(12)
              .fontColor('#D2C4B0')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 30, bottom: 15 })

        List({ space: 8 }) {
          ForEach(['all', 'pending', 'completed', 'delayed'], (s: TodoStatus | 'all') => {
            ListItem() {
              Text(s === 'all' ? '全部' : s === 'pending' ? '待处理' : s === 'completed' ? '已完成' : '已延期')
                .fontSize(13)
                .fontColor(this.statusFilter === s ? '#FFF' : '#705C53')
                .padding({ left: 16, right: 16, top: 7, bottom: 7 })
                .backgroundColor(this.statusFilter === s ? '#705C53' : '#EFEBE9')
                .borderRadius(20)
                .onClick(() => {
                  this.statusFilter = s;
                  this.fetchTodos();
                })
            }
          })
        }
        .listDirection(Axis.Horizontal)
        .height(44)
        .padding({ left: 20, right: 20 })
        .scrollBar(BarState.Off)

        List({ space: 8 }) {
          ForEach(['all', 'important_urgent', 'important_not_urgent', 'not_important_urgent', 'not_important_not_urgent'], (p: string) => {
            ListItem() {
              Text(p === 'all' ? '全部优先级' : this.getPriorityLabel(p))
                .fontSize(13)
                .fontColor(this.priorityFilter === p ? '#FFF' : '#705C53')
                .padding({ left: 16, right: 16, top: 7, bottom: 7 })
                .backgroundColor(this.priorityFilter === p ? '#705C53' : '#EFEBE9')
                .borderRadius(20)
                .onClick(() => {
                  this.priorityFilter = p;
                  this.fetchTodos();
                })
            }
          })
        }
        .listDirection(Axis.Horizontal)
        .height(44)
        .padding({ left: 20, right: 20 })
        .scrollBar(BarState.Off)

        if (this.todos.length === 0) {
          Column({ space: 12 }) {
            Text('🏔️').fontSize(52)
            Text('还没有任务，点击右下角 + 开始攀登')
              .fontSize(14)
              .fontColor('#A89982')
              .textAlign(TextAlign.Center)
              .padding({ left: 40, right: 40 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .width('100%')
        } else {
          List({ space: 12 }) {
            ForEach(this.todos, (todo: Todo) => {
              ListItem() {
                this.TodoCard(todo)
              }
            }, (todo: Todo) => todo.id.toString() + "_" + todo.priority)
          }
          .layoutWeight(1)
          .padding({ left: 20, right: 20, top: 12, bottom: 20 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeBg)

      Button({ type: ButtonType.Circle }) {
        Text('+').fontSize(28).fontColor('#FFF')
      }
      .width(52)
      .height(52)
      .backgroundColor('#705C53')
      .shadow({ radius: 12, color: '#204A3933', offsetY: 4 })
      .margin({ right: 20, bottom: 20 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/TodoBoard' });
      })
    }
    .backgroundColor(this.themeBg)
  }

  @Builder PackSection(): void {
    Column() {
      Text('Llama Pack')
        .fontSize(28)
        .fontWeight(FontWeight.Bolder)
        .fontColor('#4A3933')
        .letterSpacing(1)
        .padding({ left: 24, top: 30, bottom: 4 })
      Text('管理你的一切')
        .fontSize(12)
        .fontColor('#D2C4B0')
        .padding({ left: 24, bottom: 20 })

      List({ space: 1 }) {
        this.PackItem('🏷️ 标签管理', () => router.pushUrl({ url: 'pages/TagManage' }))
        this.PackItem('🔍 笔记搜索', () => router.pushUrl({ url: 'pages/SearchPage' }))
        this.PackItem('🎨 主题装扮', () => this.openThemeDialog())
        this.PackItem('⚙️ 设置中心', () => this.openSettingsDialog())
      }
      .backgroundColor('#FFF')
      .borderRadius(16)
      .margin({ left: 20, right: 20 })
      .shadow({ radius: 8, color: '#064A3933', offsetY: 2 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.themeBg)
  }

  @Builder PackItem(title: string, onClick: () => void): void {
    Row() {
      Text(title).fontSize(16).fontColor('#4A3933')
      Blank()
      Text('→').fontColor('#D2C4B0')
    }
    .width('100%')
    .padding(18)
    .onClick(onClick)
  }

  openThemeDialog(): void {
    if (this.themeDialogController) {
      this.themeDialogController.close();
    }
    this.themeDialogController = new CustomDialogController({
      builder: ThemeDialog({
        currentThemeId: this.currentTheme.id,
        onSelect: (themeId: number) => {
          this.switchTheme(themeId);
          if (this.themeDialogController) {
            this.themeDialogController.close();
          }
        },
        onCancel: () => {}
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.themeDialogController.open();
  }

  async openSettingsDialog(): Promise<void> {
    try {
      const data = await request<AISettingsResponse>('/settings/ai', 'GET');
      // 处理 data 可能为 null 的情况
      if (data && typeof data.provider_url === 'string') {
        this.aiProviderUrl = data.provider_url;
      } else {
        this.aiProviderUrl = '';
      }
      this.aiApiKeyInput = '';
      if (this.settingsDialogController) {
        this.settingsDialogController.close();
      }
      this.settingsDialogController = new CustomDialogController({
        builder: SettingsDialog({
          aiProviderUrl: this.aiProviderUrl,
          aiApiKeyInput: this.aiApiKeyInput,
          onSave: (url: string, key: string) => this.saveSettings(url, key),
          onCancel: () => {}
        }),
        autoCancel: true,
        alignment: DialogAlignment.Center,
        customStyle: true
      });
      this.settingsDialogController.open();
    } catch (e) {
      const error = e as Error;
      console.error('加载 AI 设置失败', error.message);
      promptAction.showToast({ message: '加载设置失败' });
    }
  }

  async saveSettings(providerUrl: string, apiKey: string): Promise<void> {
    try {
      const payload: AISettingsPayload = { provider_url: providerUrl };
      if (apiKey && apiKey.trim()) payload.api_key = apiKey.trim();
      await request<object>('/settings/ai', 'POST', payload);
      promptAction.showToast({ message: 'AI 设置已保存' });
      if (this.settingsDialogController) {
        this.settingsDialogController.close();
      }
    } catch (e) {
      const error = e as Error;
      console.error('保存 AI 设置失败', error.message);
      promptAction.showToast({ message: '保存失败' });
    }
  }

  @Builder TodoCard(todo: Todo): void {
    Column({ space: 10 }) {
      Row() {
        Text(todo.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(todo.status === 'completed' ? '#A89982' : '#4A3933')
          .decoration({
            type: todo.status === 'completed' ? TextDecorationType.LineThrough : TextDecorationType.None
          })
          .maxLines(2)
          .layoutWeight(1)

        Text(this.todoStatusConfig(todo.status).label)
          .fontSize(11)
          .fontColor(this.todoStatusConfig(todo.status).color)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.todoStatusConfig(todo.status).bg)
          .borderRadius(10)
          .margin({ left: 10 })

        Text(this.getPriorityLabel(todo.priority ?? 'important_urgent'))
          .fontSize(11)
          .fontColor(this.getPriorityColor(todo.priority ?? 'important_urgent'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.getPriorityBg(todo.priority ?? 'important_urgent'))
          .borderRadius(10)
          .margin({ left: 6 })
      }
      .width('100%')

      if (todo.deadline) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.calendar'))
            .fontSize(13)
            .fontColor(['#A89982'])
          Text(`截止：${new Date(todo.deadline).toLocaleDateString()}`)
            .fontSize(12)
            .fontColor('#A89982')
        }
      }

      Divider().color('#EFEBE9').strokeWidth(1)

      Row() {
        Row({ space: 8 }) {
          if (todo.status === 'pending' || todo.status === 'delayed') {
            Text('已完成')
              .fontSize(12)
              .fontColor('#FFF')
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor('#705C53')
              .borderRadius(10)
              .onClick(() => this.setTodoStatus(todo.id, 'completed'))

            Text(todo.status === 'pending' ? '待处理' : '已延期')
              .fontSize(12)
              .fontColor('#A89982')
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor('#EFEBE9')
              .borderRadius(10)
              .opacity(0.6)
          } else if (todo.status === 'completed') {
            Text('已完成')
              .fontSize(12)
              .fontColor('#A89982')
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor('#EFEBE9')
              .borderRadius(10)
              .opacity(0.6)

            Text(this.getFallbackLabel(todo.deadline))
              .fontSize(12)
              .fontColor('#FFF')
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor('#705C53')
              .borderRadius(10)
              .onClick(() => {
                const status = this.getFallbackStatus(todo.deadline);
                this.setTodoStatus(todo.id, status);
              })
          }
        }

        Blank()

        Row({ space: 10 }) {
          Circle({ width: 12, height: 12 }).fill('#D32F2F')
            .onClick(() => this.setTodoPriority(todo.id, 'important_urgent'))
          Circle({ width: 12, height: 12 }).fill('#F57C00')
            .onClick(() => this.setTodoPriority(todo.id, 'important_not_urgent'))
          Circle({ width: 12, height: 12 }).fill('#1976D2')
            .onClick(() => this.setTodoPriority(todo.id, 'not_important_urgent'))
          Circle({ width: 12, height: 12 }).fill('#388E3C')
            .onClick(() => this.setTodoPriority(todo.id, 'not_important_not_urgent'))

          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(18)
            .fontColor(['#D2C4B0'])
            .margin({ left: 4 })
            .onClick(() => this.deleteTodo(todo.id))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .shadow({ radius: 10, color: '#084A3933', offsetY: 4 })
  }

  @Builder NoteCard(note: Note): void {
    Column({ space: 8 }) {
      Text(note.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3933')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (note.summary && note.summary.trim() !== '') {
        Text(note.summary)
          .fontSize(14)
          .fontColor('#887A73')
          .maxLines(2)
          .lineHeight(20)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4, bottom: 4 })
      }

      Row() {
        Text(new Date(note.created_at).toLocaleDateString())
          .fontSize(11)
          .fontColor('#D2C4B0')

        Blank()

        if (note.tag_id && this.tagNameById(note.tag_id)) {
          Row() {
            Circle({ width: 4, height: 4 }).fill('#705C53').margin({ right: 6 })
            Text(this.tagNameById(note.tag_id))
              .fontSize(10)
              .fontColor('#705C53')
          }
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('#EFEBE9')
          .borderRadius(12)
        }
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .shadow({ radius: 15, color: '#0D4A3933', offsetY: 6 })
  }

  @Builder EmptyState(): void {
    Column() {
      Text('🦙').fontSize(60)
      Text('草坪空荡荡，快去采撷灵感吧').fontSize(14).fontColor('#A89982').margin({ top: 10 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }
}

@CustomDialog
struct SettingsDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });
  aiProviderUrl: string = '';
  aiApiKeyInput: string = '';
  onSave: (url: string, key: string) => void = () => {};
  onCancel: () => void = () => {};

  @State localUrl: string = '';
  @State localKey: string = '';

  aboutToAppear(): void {
    this.localUrl = this.aiProviderUrl;
    this.localKey = this.aiApiKeyInput;
  }

  build(): void {
    Column({ space: 12 }) {
      Text('AI 设置')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .padding({ top: 8 })

      TextInput({ text: this.localUrl, placeholder: 'AI Provider URL (e.g. https://api.openai.com/v1/chat/completions)' })
        .fontSize(14)
        .padding(8)
        .backgroundColor('#FFF')
        .onChange((v: string) => this.localUrl = v)

      TextInput({ text: this.localKey, placeholder: 'API Key (will be stored on server)' })
        .fontSize(14)
        .padding(8)
        .backgroundColor('#FFF')
        .onChange((v: string) => this.localKey = v)

      Row({ space: 8 }) {
        Button('取消')
          .onClick(() => {
            this.onCancel();
            this.controller.close();
          })
        Button('保存')
          .backgroundColor('#705C53')
          .fontColor('#FFF')
          .onClick(() => {
            this.onSave(this.localUrl, this.localKey);
            this.controller.close();
          })
      }
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    .backgroundColor(Color.White)
    .borderRadius(12)
    .width('90%')
  }
}

@CustomDialog
struct ThemeDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });
  currentThemeId: number = 1;
  onSelect: (themeId: number) => void = () => {};
  onCancel: () => void = () => {};

  build(): void {
    Column({ space: 16 }) {
      Text('🎨 选择主题装扮')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3933')
        .padding({ top: 8 })

      ForEach(THEMES, (theme: ThemeConfig) => {
        Row({ space: 14 }) {
          // 左侧色块预览
          Row({ space: 6 }) {
            Circle({ width: 18, height: 18 }).fill(theme.primary)
            Circle({ width: 18, height: 18 }).fill(theme.secondary)
            Circle({ width: 18, height: 18 }).fill(theme.accent)
          }

          Text(theme.name)
            .fontSize(15)
            .fontColor('#4A3933')
            .layoutWeight(1)

          // 当前选中标记
          if (this.currentThemeId === theme.id) {
            Text('✓')
              .fontSize(16)
              .fontColor('#705C53')
              .fontWeight(FontWeight.Bold)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .backgroundColor(this.currentThemeId === theme.id ? '#EFEBE9' : '#FAFAFA')
        .borderRadius(12)
        .onClick(() => {
          this.onSelect(theme.id);
        })
      }, (theme: ThemeConfig) => theme.id.toString())

      Button('取消')
        .width('100%')
        .backgroundColor('#EFEBE9')
        .fontColor('#705C53')
        .onClick(() => {
          this.onCancel();
          this.controller.close();
        })
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    .backgroundColor(Color.White)
    .borderRadius(16)
    .width('90%')
  }
}
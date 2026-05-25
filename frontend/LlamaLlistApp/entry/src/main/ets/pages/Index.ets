import { request } from '../common/network/httpClient';
import { Note } from '../models/Note';
import { Tag } from '../models/Tag';
import { Todo, TodoStatus, TodoPriority } from '../models/Todo';
import { THEMES, ThemeConfig } from '../common/constants/Theme';
import { appTheme } from '../common/constants/ThemeManager';
import { encryptApiKeyNative, decryptApiKeyNative } from '../common/native/MarkdownNative';
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
  model_name: string;
}

interface AISettingsPayload {
  provider_url: string;
  model_name: string;
  api_key?: string;
}

interface AIModelCheckPayload {
  provider_url: string;
  model_name: string;
  api_key: string;
}

@Entry
@Component
struct Index {
  @State notes: Note[] = [];
  @State tags: Tag[] = [];
  @State currentIndex: number = 0;
  private controller: TabsController = new TabsController();

  @State selectedTagId: number | null = null;
  @State selectedNoteId: number | null = null;
  @State notesPaneWidth: number = 0;
  @State selectedCategory: number = 0;
  @State aiProviderUrl: string = '';
  @State aiModelName: string = 'deepseek-chat';
  @State aiApiKeyInput: string = '';
  @State settingsDialogController: CustomDialogController | null = null;
  @State themeDialogController: CustomDialogController | null = null;
  @State currentTheme: ThemeConfig = THEMES[0];
  @StorageLink('themeBg') themeBg: string = '#F9F8F4';
  @StorageLink('themePrimary') themePrimary: string = '#705C53';
  @StorageLink('themeText') themeText: string = '#4A3933';
  @StorageLink('themeSecondary') themeSecondary: string = '#A89982';
  @StorageLink('themeAccent') themeAccent: string = '#D9A85F';
  @StorageLink('themeCard') themeCard: string = '#FFFFFF';
  @StorageLink('themeSoft') themeSoft: string = '#EEF3E5';
  @StorageLink('themeMascot') themeMascot: string = 'LL';

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

      this.todos = this.sortTodos(data ?? []);
    } catch (e) {
      const error = e as Error;
      console.error('加载待办失败', error.message);
    }
  }

  async createTodo(): Promise<void> {
    const title = this.todoTitleInput.trim();
    if (!title) {
      promptAction.showToast({ message: '待办标题不能为空' });
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
      promptAction.showToast({ message: '任务已添加' });
    } catch (e) {
      const error = e as Error;
      console.error('添加待办失败', error.message);
      promptAction.showToast({ message: '添加失败' });
    } finally {
      this.isSubmittingTodo = false;
    }
  }

  private sortTodos(list: Todo[]): Todo[] {
    return list.sort((a: Todo, b: Todo) => {
      if (a.status === 'completed' && b.status !== 'completed') return 1;
      if (a.status !== 'completed' && b.status === 'completed') return -1;

      const priorityOrder: Record<string, number> = {
        'important_urgent': 0,
        'not_important_urgent': 1,
        'important_not_urgent': 2,
        'not_important_not_urgent': 3
      };
      const aPriority = priorityOrder[a.priority ?? 'important_urgent'];
      const bPriority = priorityOrder[b.priority ?? 'important_urgent'];
      if (aPriority !== bPriority) return aPriority - bPriority;

      if (!a.deadline && !b.deadline) return 0;
      if (!a.deadline) return 1;
      if (!b.deadline) return -1;

      const timeA = new Date(a.deadline).getTime();
      const timeB = new Date(b.deadline).getTime();
      return timeA - timeB;
    });
  }

  private todoMatchesCurrentFilter(todo: Todo): boolean {
    const statusMatched = this.statusFilter === 'all' || todo.status === this.statusFilter;
    const priorityMatched = this.priorityFilter === 'all' || todo.priority === this.priorityFilter;
    return statusMatched && priorityMatched;
  }

  private updateTodoStatusLocal(id: number, status: TodoStatus): void {
    const nextTodos = this.todos.map((t: Todo): Todo => {
      if (t.id === id) {
        return {
          id: t.id,
          title: t.title,
          status: status,
          priority: t.priority,
          deadline: t.deadline,
          note_id: t.note_id
        };
      }
      return t;
    }).filter((t: Todo): boolean => this.todoMatchesCurrentFilter(t));
    this.todos = this.sortTodos(nextTodos);
  }

  private updateTodoPriorityLocal(id: number, priority: TodoPriority): void {
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
    }).filter((t: Todo): boolean => this.todoMatchesCurrentFilter(t));
    this.todos = this.sortTodos(nextTodos);
  }

  private nextStatusForCheck(todo: Todo): TodoStatus {
    return todo.status === 'completed' ? this.getFallbackStatus(todo.deadline) : 'completed';
  }

  async toggleTodoDone(todo: Todo): Promise<void> {
    await this.setTodoStatus(todo.id, this.nextStatusForCheck(todo));
  }

  async setTodoStatus(id: number, status: TodoStatus): Promise<void> {
    const previousTodos = this.todos;
    this.updateTodoStatusLocal(id, status);
    try {
      const payload: TodoUpdateRequest = { status };
      await request<Todo>(`/todos/${id}`, 'PUT', payload);
    } catch (e) {
      this.todos = previousTodos;
      const error = e as Error;
      console.error('更新状态失败', error.message);
      promptAction.showToast({ message: '更新状态失败' });
    }
  }

  async setTodoPriority(id: number, priority: TodoPriority): Promise<void> {
    const previousTodos = this.todos;
    const currentStatus = this.getCurrentStatusById(id);
    this.updateTodoPriorityLocal(id, priority);
    try {
      const payload: TodoUpdateRequest = { status: currentStatus, priority };
      await request<Todo>(`/todos/${id}`, 'PUT', payload);
      promptAction.showToast({ message: '优先级已更新' });
    } catch (e) {
      this.todos = previousTodos;
      const error = e as Error;
      console.error('更新优先级失败', error.message);
      promptAction.showToast({ message: '更新优先级失败' });
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
      'important_urgent': '重要且紧急',
      'important_not_urgent': '重要不紧急',
      'not_important_urgent': '紧急不重要',
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



  private countAIProcessedNotes(): number {
    return this.notes.filter((note: Note) => note.summary && note.summary.trim() !== '').length;
  }

  private countPendingTodos(): number {
    return this.todos.filter((todo: Todo) => todo.status === 'pending').length;
  }

  private countCompletedTodos(): number {
    return this.todos.filter((todo: Todo) => todo.status === 'completed').length;
  }

  private countDelayedTodos(): number {
    return this.todos.filter((todo: Todo) => todo.status === 'delayed').length;
  }

  private countTodayDueTodos(): number {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const end = start + 24 * 60 * 60 * 1000;
    return this.todos.filter((todo: Todo) => {
      if (!todo.deadline || todo.status === 'completed') return false;
      const t = new Date(todo.deadline).getTime();
      return t >= start && t < end;
    }).length;
  }

  private safeSummary(note: Note): string {
    if (note.summary && note.summary.trim() !== '') {
      return note.summary.trim();
    }
    return '';
  }

  private themeCoverResource(): Resource {
    if (this.currentTheme.id === 2) {
      return $r('app.media.note_bg_andes');
    }
    if (this.currentTheme.id === 3) {
      return $r('app.media.note_bg_wool');
    }
    if (this.currentTheme.id === 4) {
      return $r('app.media.note_bg_sunrise');
    }
    if (this.currentTheme.id === 5) {
      return $r('app.media.note_bg_ranch');
    }
    if (this.currentTheme.id === 6) {
      return $r('app.media.note_bg_caravan');
    }
    return $r('app.media.note_bg_meadow');
  }

  private noteCoverResource(note?: Note): Resource {
    const key = note && note.view_type ? note.view_type : '';
    if (key === 'andes') return $r('app.media.note_bg_andes');
    if (key === 'wool') return $r('app.media.note_bg_wool');
    if (key === 'sunrise') return $r('app.media.note_bg_sunrise');
    if (key === 'ranch') return $r('app.media.note_bg_ranch');
    if (key === 'caravan') return $r('app.media.note_bg_caravan');
    if (key === 'meadow') return $r('app.media.note_bg_meadow');
    return this.themeCoverResource();
  }

  private isWideLayout(): boolean {
    return this.notesPaneWidth >= 900;
  }

  private currentSelectedNote(): Note | null {
    if (this.notes.length === 0) return null;
    if (this.selectedNoteId !== null) {
      const found = this.notes.find((n: Note) => n.id === this.selectedNoteId);
      if (found) return found;
    }
    return this.notes[0];
  }

  private firstImagePath(note: Note): string {
    if (!note.image_paths || note.image_paths.trim() === '') {
      return '';
    }
    const paths = note.image_paths.split(',').filter((path: string) => path.trim() !== '');
    return paths.length > 0 ? paths[0] : '';
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
        }.tabBar(this.TabBuilder('行囊', 2, 'sys.symbol.person'))
      }
      .onChange((index: number) => {
        this.currentIndex = index;
        if (index === 1) {
          this.fetchTodos();
        }
      })
      .barHeight(60)
      .backgroundColor(this.themeCard)
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
        .fontColor([this.currentIndex === index ? this.themePrimary : this.themeSecondary])
      Text(title)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentIndex === index ? this.themePrimary : this.themeSecondary)
        .margin({ top: 4 })
    }
    .width('100%')
  }

  @Builder MeadowHeader(): void {
    Row() {
      Text(this.themeMascot)
        .fontSize(30)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.themeSoft)
        .borderRadius(16)
        .margin({ right: 10 })

      Column() {
        Text('Llama Meadow')
          .fontSize(28)
          .fontWeight(FontWeight.Bolder)
          .fontColor(this.themeText)
          .letterSpacing(1)
        Text('发现并记录你的灵感碎片')
          .fontSize(12)
          .fontColor(this.themeSecondary)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(22)
        .fontColor([this.themePrimary])
        .onClick(() => router.pushUrl({ url: 'pages/SearchPage' }))
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 30, bottom: 15 })
  }

  @Builder
  NotesTab(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.LlamaDashboardHero()

        Scroll() {
          Row({ space: 12 }) {
            Text('全部')
              .fontSize(14)
              .fontWeight(this.selectedTagId === null ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.selectedTagId === null ? '#FFFFFF' : this.themePrimary)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .backgroundColor(this.selectedTagId === null ? this.themePrimary : this.themeSoft)
              .borderRadius(20)
              .onClick(() => {
                this.selectedTagId = null;
                this.fetchNotes();
              })

            ForEach(this.tags, (tag: Tag) => {
              Text(tag.name)
                .fontSize(14)
                .fontWeight(this.selectedTagId === tag.id ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.selectedTagId === tag.id ? '#FFFFFF' : this.themePrimary)
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .backgroundColor(this.selectedTagId === tag.id ? this.themePrimary : this.themeSoft)
                .borderRadius(20)
                .onClick(() => {
                  this.selectedTagId = tag.id;
                  this.fetchNotesByTag(tag.id);
                })
            }, (tag: Tag) => tag.id.toString())

            Text('+')
              .fontSize(20)
              .fontColor('#A89982')
              .padding({ left: 12, right: 12 })
              .onClick(() => router.pushUrl({ url: 'pages/TagManage' }))
          }
          .padding({ left: 24, right: 24 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .margin({ top: 12, bottom: 10 })

        if (this.notes.length === 0) {
          this.EmptyState()
        } else if (this.isWideLayout()) {
          Row({ space: 14 }) {
            List({ space: 16 }) {
              ForEach(this.notes, (note: Note) => {
                ListItem() {
                  this.NoteCard(note)
                }
                .backgroundColor(this.selectedNoteId === note.id ? this.themeSoft : '#00FFFFFF')
                .borderRadius(18)
                .border({ width: this.selectedNoteId === note.id ? 2 : 0, color: this.themePrimary })
                .padding(2)
                .swipeAction({
                  end: {
                    builder: () => { this.noteSwipeBuilder(note.id) },
                    onAction: () => {},
                    actionAreaDistance: 80,
                  },
                  edgeEffect: SwipeEdgeEffect.Spring
                })
                .onClick(() => {
                  if (this.selectedNoteId === note.id) {
                    router.pushUrl({ url: 'pages/NoteEdit', params: { id: note.id } });
                    return;
                  }
                  this.selectedNoteId = note.id;
                })
              }, (item: Note) => item.id.toString())
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)

            Column() {
              Scroll() {
                this.NoteDetailPane(this.currentSelectedNote())
              }
              .scrollable(ScrollDirection.Vertical)
              .scrollBar(BarState.Auto)
              .edgeEffect(EdgeEffect.Spring)
              .layoutWeight(1)
            }
            .layoutWeight(1)
          }
          .layoutWeight(1)
          .padding({ left: 20, right: 20, top: 2, bottom: 0 })
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
          .padding({ left: 20, right: 20, top: 2, bottom: 0 })
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((_: Area, area: Area) => {
        this.notesPaneWidth = Number(area.width);
      })

      Button({ type: ButtonType.Circle }) {
        Text('+').fontSize(28).fontColor('#FFF')
      }
      .width(52)
      .height(52)
      .backgroundColor(this.themePrimary)
      .shadow({ radius: 12, color: '#204A3933', offsetY: 4 })
      .margin({ right: 20, bottom: 20 })
      .onClick(() => router.pushUrl({ url: 'pages/NoteEdit' }))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBg)
  }


  @Builder
  LlamaDashboardHero(): void {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(this.themeCoverResource())
        .width('100%')
        .height(242)
        .objectFit(ImageFit.Cover)
        .opacity(0.74)

      Column({ space: 14 }) {
        Row({ space: 12 }) {
          Column({ space: 5 }) {
            Text('Llama Llist')
              .fontSize(28)
              .fontWeight(FontWeight.Bolder)
              .fontColor(this.themeText)
            Text(this.currentTheme.name + '  ' + this.currentTheme.slogan)
              .fontSize(12)
              .fontColor(this.themeText)
              .opacity(0.72)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Image($r('app.media.llama_mascot'))
            .width(58)
            .height(58)
            .objectFit(ImageFit.Contain)
            .backgroundColor('#CCFFFFFF')
            .borderRadius(22)
            .shadow({ radius: 10, color: '#184A3933', offsetY: 4 })

          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(17)
              .fontColor([this.themePrimary])
            Text('搜索')
              .fontSize(12)
              .fontColor(this.themePrimary)
              .fontWeight(FontWeight.Medium)
          }
          .height(38)
          .padding({ left: 11, right: 12 })
          .backgroundColor('#E6FFFFFF')
          .borderRadius(18)
          .shadow({ radius: 8, color: '#124A3933', offsetY: 3 })
          .onClick(() => router.pushUrl({ url: 'pages/SearchPage' }))
        }
        .width('100%')

        Row({ space: 9 }) {
          this.DashboardMetric('灵感笔记', this.notes.length.toString(), 'sys.symbol.house', this.themeSoft)
          this.DashboardMetric('待办清单', this.countPendingTodos().toString(), 'sys.symbol.checkmark_circle', '#F8F3E5')
          this.DashboardMetric('AI 整理', this.countAIProcessedNotes().toString(), 'sys.symbol.magnifyingglass', '#EEF4EA')
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 34, bottom: 18 })
    }
    .width('100%')
    .height(248)
    .clip(true)
  }

  @Builder
  DashboardMetric(label: string, value: string, icon: string, bg: string): void {
    Column({ space: 5 }) {
      SymbolGlyph($r(icon))
        .fontSize(20)
        .fontColor([this.themePrimary])
      Text(label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeText)
        .maxLines(1)
      Text(value + ' 项')
        .fontSize(10)
        .fontColor(this.themeSecondary)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(76)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(bg)
    .borderRadius(15)
    .border({ width: 1, color: '#40FFFFFF' })
    .shadow({ radius: 8, color: '#104A3933', offsetY: 3 })
  }

  @Builder
  HomeInsightPanel(): void {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('今日概览')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeText)

          Text('笔记、待办和 AI 整理状态一眼可见')
            .fontSize(12)
            .fontColor('#A89982')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // Text('AI 整理')
        //   .fontSize(11)
        //   .fontColor('#6F5647')
        //   .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        //   .backgroundColor('#F3EBDD')
        //   .borderRadius(14)
      }
      .width('100%')

      Row({ space: 10 }) {
        this.InsightItem('笔记', this.notes.length.toString(), '#F7EFE6')
        this.InsightItem('AI 整理', this.countAIProcessedNotes().toString(), '#EEF4EA')
        this.InsightItem('待处理', this.countPendingTodos().toString(), '#F4EFE8')
        this.InsightItem('今日到期', this.countTodayDueTodos().toString(), '#FFF4E6')
      }
      .width('100%')

      if (this.countAIProcessedNotes() === 0 && this.notes.length > 0) {
        Row({ space: 8 }) {
          Text('提示')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#8BA078')
            .borderRadius(10)

          Text('进入任意笔记点击 AI 整理，摘要会回写并显示在首页卡片中。')
            .fontSize(12)
            .fontColor('#8E7D6B')
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor('#FBF8F3')
        .borderRadius(12)
      }
    }
    .width('95%')
    .padding(16)
    .margin({ left: 20, right: 20, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .shadow({ radius: 12, color: '#0A4A3933', offsetY: 4 })
  }

  @Builder
  InsightItem(label: string, value: string, bg: string): void {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3933')

      Text(label)
        .fontSize(11)
        .fontColor('#8E7D6B')
        .maxLines(1)
    }
    .layoutWeight(1)
    .padding({ top: 11, bottom: 11 })
    .backgroundColor(bg)
    .borderRadius(16)
  }

  @Builder
  NoteDetailPane(note: Note | null): void {
    Column({ space: 12 }) {
      if (!note) {
        Column({ space: 8 }) {
          Text('请选择一条笔记')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeText)
          Text('左侧点击笔记后在这里查看详情')
            .fontSize(13)
            .fontColor(this.themeSecondary)
        }
        .width('100%')
        .padding({ top: 30 })
        .alignItems(HorizontalAlign.Start)
      } else {
        Text(note.title)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeText)
          .width('100%')

        Row({ space: 8 }) {
          Text(new Date(note.updated_at ?? note.created_at).toLocaleDateString())
            .fontSize(12)
            .fontColor(this.themeSecondary)

          if (note.tag_id && this.tagNameById(note.tag_id)) {
            Text(this.tagNameById(note.tag_id))
              .fontSize(11)
              .fontColor(this.themePrimary)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(this.themeSoft)
              .borderRadius(10)
          }
        }
        .width('100%')

        if (note.summary && note.summary.trim() !== '') {
          Text(note.summary)
            .fontSize(14)
            .lineHeight(22)
            .fontColor(this.themeText)
            .width('100%')
            .padding(12)
            .backgroundColor(this.themeSoft)
            .borderRadius(12)
        }

        Text(note.content && note.content.trim() !== '' ? note.content : '暂无正文内容')
          .fontSize(14)
          .lineHeight(22)
          .fontColor(this.themeText)
          .width('100%')

        Row({ space: 10 }) {
          Button('编辑')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor(this.themePrimary)
            .borderRadius(12)
            .onClick(() => router.pushUrl({ url: 'pages/NoteEdit', params: { id: note.id } }))
          Button('搜索相关')
            .fontSize(13)
            .fontColor(this.themePrimary)
            .backgroundColor(this.themeSoft)
            .borderRadius(12)
            .onClick(() => router.pushUrl({ url: 'pages/SearchPage' }))
        }
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.themeCard)
    .borderRadius(20)
    .shadow({ radius: 10, color: '#104A3933', offsetY: 3 })
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

  private todoCountByStatus(status: TodoStatus): number {
    return this.todos.filter((todo: Todo) => todo.status === status).length;
  }

  private urgentTodoCount(): number {
    return this.todos.filter((todo: Todo) => todo.priority === 'important_urgent' || todo.priority === 'not_important_urgent').length;
  }

  @Builder TodoOverviewPanel(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Image(this.themeCoverResource())
        .width('100%')
        .height(118)
        .objectFit(ImageFit.Cover)
        .opacity(0.22)

      Column({ space: 14 }) {
        Row() {
          Column({ space: 4 }) {
            Text('今日任务牧场')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeText)
            Text('点击圆圈完成任务，彩色圆点调整紧急程度')
              .fontSize(11)
              .fontColor(this.themeSecondary)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Image($r('app.media.llama_mascot'))
            .width(54)
            .height(54)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')

        Row({ space: 8 }) {
          this.TodoStatChip('待处理', this.todoCountByStatus('pending').toString(), this.themePrimary, this.themeSoft)
          this.TodoStatChip('已延期', this.todoCountByStatus('delayed').toString(), '#C0392B', '#FDECEC')
          this.TodoStatChip('紧急', this.urgentTodoCount().toString(), '#D97B33', '#FFF3E0')
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    }
    .width('100%')
    .height(150)
    .backgroundColor(this.themeCard)
    .borderRadius(22)
    .clip(true)
    .shadow({ radius: 10, color: '#104A3933', offsetY: 4 })
    .margin({ left: 20, right: 20, bottom: 14 })
  }

  @Builder TodoStatChip(label: string, value: string, color: string, bg: string): void {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(10)
        .fontColor(this.themeSecondary)
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 9 })
    .backgroundColor(bg)
    .borderRadius(14)
  }

  @Builder FilterTitle(label: string): void {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.themeSecondary)
      .width('100%')
      .padding({ left: 24, right: 24, top: 2, bottom: 6 })
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
            Text('逐步翻越每一个目标')
              .fontSize(12)
              .fontColor('#D2C4B0')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 30, bottom: 15 })

        this.TodoOverviewPanel()

        this.FilterTitle('状态筛选')
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

        this.FilterTitle('优先级筛选')
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
            Image($r('app.media.llama_mascot'))
              .width(86)
              .height(86)
              .objectFit(ImageFit.Contain)
              .opacity(0.82)
            Text('还没有任务，点击右下角 + 开始安排')
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
                this.TodoCardCompact(todo)
              }
            }, (todo: Todo) => todo.id.toString() + "_" + todo.status + "_" + todo.priority)
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
      .backgroundColor(this.themePrimary)
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
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(this.themeCoverResource())
          .width('100%')
          .height(155)
          .objectFit(ImageFit.Cover)
          .opacity(0.7)

        Row() {
          Column({ space: 5 }) {
            Text('Llama Pack')
              .fontSize(28)
              .fontWeight(FontWeight.Bolder)
              .fontColor(this.themeText)
            Text('主题、模板、标签和 AI 设置')
              .fontSize(12)
              .fontColor(this.themeText)
              .opacity(0.72)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Image($r('app.media.llama_mascot'))
            .width(70)
            .height(70)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 18 })
      }
      .width('100%')
      .height(165)

      List({ space: 1 }) {
        this.PackItem('标签牧场', () => router.pushUrl({ url: 'pages/TagManage' }))
        this.PackItem('灵感搜索', () => router.pushUrl({ url: 'pages/SearchPage' }))
        this.PackItem('主题装扮', () => this.openThemeDialog())
        this.PackItem('AI 设置中心', () => this.openSettingsDialog())
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
      Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeText)
      Blank()
      Text('>').fontColor('#D2C4B0')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.themeCard)
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
      if (data && typeof data.model_name === 'string' && data.model_name.trim()) {
        this.aiModelName = data.model_name;
      } else {
        this.aiModelName = 'deepseek-chat';
      }
      this.aiApiKeyInput = '';
      if (this.settingsDialogController) {
        this.settingsDialogController.close();
      }
      this.settingsDialogController = new CustomDialogController({
        builder: SettingsDialog({
          aiProviderUrl: this.aiProviderUrl,
          aiModelName: this.aiModelName,
          aiApiKeyInput: this.aiApiKeyInput,
          onSave: (url: string, model: string, key: string) => this.saveSettings(url, model, key),
          onCheck: (url: string, model: string, key: string) => this.checkAIModel(url, model, key),
          onCancel: () => {}
        }),
        autoCancel: true,
        alignment: DialogAlignment.Center,
        customStyle: true
      });
      this.settingsDialogController.open();
    } catch (e) {
      console.error('加载 AI 设置失败', `${e}`);
      promptAction.showToast({ message: '加载设置失败' });
    }
  }

  async saveSettings(providerUrl: string, modelName: string, apiKey: string): Promise<void> {
    try {
      const payload: AISettingsPayload = { provider_url: providerUrl, model_name: modelName };
      const trimmed = (apiKey || '').trim();
      if (trimmed) {
        const salt = `${providerUrl}|${modelName}`;
        const enc = encryptApiKeyNative(trimmed, salt);
        payload.api_key = enc.length > 0 ? JSON.stringify(enc) : '';
      }
      await request<object>('/settings/ai', 'POST', payload);
      this.aiProviderUrl = providerUrl;
      this.aiModelName = modelName;
      promptAction.showToast({ message: 'AI 设置已保存' });
      if (this.settingsDialogController) {
        this.settingsDialogController.close();
      }
    } catch (e) {
      console.error('保存 AI 设置失败', `${e}`);
      promptAction.showToast({ message: '保存失败' });
    }
  }

  async checkAIModel(providerUrl: string, modelName: string, apiKey: string): Promise<void> {
    const url = providerUrl.trim();
    const model = modelName.trim();
    const key = apiKey.trim();
    if (!url || !model || !key) {
      throw new Error('请填写模型名称、接口地址与 Key');
    }
    try {
      const salt = `${url}|${model}`;
      const enc = encryptApiKeyNative(key, salt);
      const payload: AIModelCheckPayload = { provider_url: url, model_name: model, api_key: enc.length > 0 ? JSON.stringify(enc) : '' };
      await request<object>('/settings/ai/check', 'POST', payload);
    } catch (e) {
      console.error('模型检测失败', `${e}`);
      throw new Error(`${e}` || '连接失败');
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

  @Builder TodoCardCompact(todo: Todo): void {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (todo.status === 'completed') {
          Text('✓')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
      }
        .width(18)
        .height(18)
        .borderRadius(9)
        .border({ width: 1.4, color: todo.status === 'completed' ? this.themePrimary : this.themeSecondary })
        .backgroundColor(todo.status === 'completed' ? this.themePrimary : '#00FFFFFF')
        .onClick(() => this.toggleTodoDone(todo))

      Column({ space: 8 }) {
        Row() {
          Text(todo.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(todo.status === 'completed' ? this.themeSecondary : this.themeText)
            .decoration({
              type: todo.status === 'completed' ? TextDecorationType.LineThrough : TextDecorationType.None
            })
            .maxLines(2)
            .layoutWeight(1)

          Text(this.todoStatusConfig(todo.status).label)
            .fontSize(11)
            .fontColor(this.todoStatusConfig(todo.status).color)
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor(this.todoStatusConfig(todo.status).bg)
            .borderRadius(12)
        }
        .width('100%')

        Row() {
          Text(this.getPriorityLabel(todo.priority ?? 'important_urgent'))
            .fontSize(11)
            .fontColor(this.getPriorityColor(todo.priority ?? 'important_urgent'))
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor(this.getPriorityBg(todo.priority ?? 'important_urgent'))
            .borderRadius(12)

          if (todo.deadline) {
            Text(new Date(todo.deadline).toLocaleDateString())
              .fontSize(11)
              .fontColor(this.themeSecondary)
              .margin({ left: 8 })
          }

          Blank()

          Row({ space: 8 }) {
            Circle({ width: 12, height: 12 }).fill('#D32F2F')
              .opacity(todo.priority === 'important_urgent' ? 1 : 0.45)
              .onClick(() => this.setTodoPriority(todo.id, 'important_urgent'))
            Circle({ width: 12, height: 12 }).fill('#F57C00')
              .opacity(todo.priority === 'important_not_urgent' ? 1 : 0.45)
              .onClick(() => this.setTodoPriority(todo.id, 'important_not_urgent'))
            Circle({ width: 12, height: 12 }).fill('#1976D2')
              .opacity(todo.priority === 'not_important_urgent' ? 1 : 0.45)
              .onClick(() => this.setTodoPriority(todo.id, 'not_important_urgent'))
            Circle({ width: 12, height: 12 }).fill('#388E3C')
              .opacity(todo.priority === 'not_important_not_urgent' ? 1 : 0.45)
              .onClick(() => this.setTodoPriority(todo.id, 'not_important_not_urgent'))
          }
          .margin({ right: 10 })

          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(17)
            .fontColor([this.themeSecondary])
            .onClick(() => this.deleteTodo(todo.id))
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 15, right: 15, top: 13, bottom: 13 })
    .backgroundColor('#DFFFFFFF')
    .borderRadius(18)
    .shadow({ radius: 8, color: '#084A3933', offsetY: 3 })
  }

  @Builder NoteCard(note: Note): void {
    Column({ space: 12 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        if (this.firstImagePath(note) !== '') {
          Image(this.firstImagePath(note))
            .width('100%')
            .height(116)
            .objectFit(ImageFit.Cover)
            .borderRadius(18)
        } else {
          Image(this.noteCoverResource(note))
            .width('100%')
            .height(116)
            .objectFit(ImageFit.Cover)
            .borderRadius(18)
            .opacity(0.82)
        }

        Text(this.safeSummary(note) !== '' ? 'AI 已整理' : '等待整理')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(this.safeSummary(note) !== '' ? this.themePrimary : '#887A73')
          .borderRadius(12)
          .margin({ left: 10, bottom: 10 })
      }
      .width('100%')
      .height(116)

      Row() {
        Column({ space: 5 }) {
          Text(note.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4A3933')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 8 }) {
            Text(new Date(note.updated_at ?? note.created_at).toLocaleDateString())
              .fontSize(11)
              .fontColor('#B8A996')

            if (note.tag_id && this.tagNameById(note.tag_id)) {
              Text(this.tagNameById(note.tag_id))
                .fontSize(11)
                .fontColor(this.themePrimary)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(this.themeSoft)
                .borderRadius(10)
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.safeSummary(note) !== '') {
          Text('AI 摘要')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themePrimary)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(this.themeSoft)
            .borderRadius(13)
        } else {
          Text('未整理')
            .fontSize(11)
            .fontColor('#A89982')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(this.themeSoft)
            .borderRadius(13)
        }
      }
      .width('100%')

      if (this.safeSummary(note) !== '') {
        Column({ space: 6 }) {
          Text(this.safeSummary(note))
            .fontSize(14)
            .fontColor('#6F6254')
            .lineHeight(21)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor(this.themeSoft)
        .borderRadius(14)
      } else if (note.content && note.content.trim() !== '') {
        Text(note.content.trim())
          .fontSize(14)
          .fontColor('#9A8B7A')
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Text('暂无正文，进入笔记补充内容后可使用 AI 整理。')
          .fontSize(13)
          .fontColor('#B8A996')
      }

      Row({ space: 8 }) {
        Row({ space: 5 }) {
          Circle({ width: 5, height: 5 }).fill(this.safeSummary(note) !== '' ? '#8BA078' : '#D2C4B0')
          Text(this.safeSummary(note) !== '' ? '已形成 AI 摘要' : '等待 AI 整理')
            .fontSize(11)
            .fontColor(this.safeSummary(note) !== '' ? '#6F8062' : '#A89982')
        }

        Blank()

        Text('查看')
          .fontSize(12)
          .fontColor(this.themePrimary)
          .padding({ left: 11, right: 11, top: 5, bottom: 5 })
          .backgroundColor(this.themeSoft)
          .borderRadius(12)
      }
      .width('100%')
    }
    .padding(18)
    .backgroundColor(this.themeCard)
    .borderRadius(24)
    .shadow({ radius: 16, color: '#124A3933', offsetY: 6 })
  }

  @Builder EmptyState(): void {
    Column() {
      Text('Llama Llist').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#705C53')
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
  aiModelName: string = 'deepseek-chat';
  aiApiKeyInput: string = '';
  onSave: (url: string, model: string, key: string) => Promise<void> = async () => {};
  onCheck: (url: string, model: string, key: string) => Promise<void> = async () => {};
  onCancel: () => void = () => {};

  @State localUrl: string = '';
  @State localModel: string = 'deepseek-chat';
  @State localKey: string = '';
  @State checkResultText: string = '';
  @State checkResultSuccess: boolean = false;

  aboutToAppear(): void {
    this.localUrl = this.aiProviderUrl;
    this.localModel = this.aiModelName || 'deepseek-chat';
    this.localKey = this.aiApiKeyInput;
  }

  build(): void {
    Column({ space: 12 }) {
      Text('AI 设置')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .padding({ top: 8 })

      TextInput({ text: this.localModel, placeholder: 'Model Name (e.g. deepseek-chat)' })
        .fontSize(14)
        .padding(8)
        .backgroundColor('#FFF')
        .onChange((v: string) => this.localModel = v)

      TextInput({ text: this.localUrl, placeholder: 'Provider URL (e.g. https://api.openai.com/v1/chat/completions)' })
        .fontSize(14)
        .padding(8)
        .backgroundColor('#FFF')
        .onChange((v: string) => this.localUrl = v)

      TextInput({ text: this.localKey, placeholder: 'API Key' })
        .fontSize(14)
        .padding(8)
        .backgroundColor('#FFF')
        .onChange((v: string) => this.localKey = v)

      if (this.checkResultText) {
        Text(this.checkResultText)
          .fontSize(13)
          .fontColor(this.checkResultSuccess ? '#2E7D32' : '#C62828')
          .width('100%')
      }

      Row({ space: 8 }) {
        Button('取消')
          .onClick(() => {
            this.onCancel();
            this.controller.close();
          })
        Button('测试连接')
          .backgroundColor('#EFEBE9')
          .fontColor('#705C53')
          .onClick(async () => {
            const url = this.localUrl.trim();
            const model = this.localModel.trim();
            const key = this.localKey.trim();
            if (!url || !model || !key) {
              this.checkResultSuccess = false;
              this.checkResultText = '请完整填写模型名称、接口地址与 Key';
              return;
            }
            this.checkResultText = '连接测试中...';
            try {
              const url = this.localUrl.trim();
              const model = this.localModel.trim();
              const key = this.localKey.trim();
              if (!url || !model || !key) {
                this.checkResultSuccess = false;
                this.checkResultText = '请完整填写模型名称、接口地址与 Key';
                return;
              }
              this.checkResultText = '连接测试中...';
              await this.onCheck(url, model, key);
              this.checkResultSuccess = true;
              this.checkResultText = '连接成功';
            } catch (e) {
              this.checkResultSuccess = false;
              this.checkResultText = `${e}` || '连接失败';
            }
          })
        Button('保存')
          .backgroundColor('#705C53')
          .fontColor('#FFF')
          .onClick(async () => {
            try {
              await this.onSave(this.localUrl, this.localModel, this.localKey);
              this.controller.close();
            } catch (e) {
              this.checkResultSuccess = false;
              this.checkResultText = `${e}` || '保存失败';
            }
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
      Text('选择主题装扮')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3933')
        .padding({ top: 8 })

      ForEach(THEMES, (theme: ThemeConfig) => {
        Row({ space: 14 }) {
          Text(theme.mascot)
            .fontSize(24)
            .width(34)
            .height(34)
            .textAlign(TextAlign.Center)
            .backgroundColor(theme.soft)
            .borderRadius(12)

          // 左侧色块预览
          Row({ space: 6 }) {
            Circle({ width: 18, height: 18 }).fill(theme.primary)
            Circle({ width: 18, height: 18 }).fill(theme.secondary)
            Circle({ width: 18, height: 18 }).fill(theme.accent)
          }

          Column({ space: 3 }) {
            Text(theme.name)
              .fontSize(15)
              .fontColor('#4A3933')
              .fontWeight(FontWeight.Medium)
            Text(theme.slogan)
              .fontSize(11)
              .fontColor(theme.primary)
          }
          .alignItems(HorizontalAlign.Start)
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
        .backgroundColor(this.currentThemeId === theme.id ? theme.soft : '#FAFAFA')
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

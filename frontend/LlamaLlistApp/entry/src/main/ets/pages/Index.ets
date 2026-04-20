import { request } from '../common/network/httpClient';
import { Note } from '../models/Note';
import { Tag } from '../models/Tag';
import { Todo, TodoStatus, TodoPriority } from '../models/Todo';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

interface TodoCreateRequest {
  title: string;
  deadline?: string;
}

interface TodoUpdateRequest {
  status: TodoStatus;
  priority?:string;
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

@Entry
@Component
struct Index {
  @State notes: Note[] = [];
  @State tags: Tag[] = [];
  @State currentIndex: number = 0;
  private controller: TabsController = new TabsController();

  // 笔记分类
  // @State categories: string[] = ['全部', '📚 书架', '🌿 心情', '✍️ 随笔', '💼 会议', '＋'];
  @State selectedTagId: number | null = null; // 新增：记录当前选中的标签ID，null代表“全部”
  @State selectedCategory: number = 0;

  // 待办相关状态
  @State todos: Todo[] = [];
  @State todoTitleInput: string = '';
  @State todoDeadlineInput: string = '';
  @State statusFilter: TodoStatus | 'all' = 'all';
  @State priorityFilter: string | 'all' = 'all';
  @State isSubmittingTodo: boolean = false;
  @State showTodoInput: boolean = false;

  onPageShow() {
    this.fetchNotes();
    if (this.currentIndex === 1) {
      this.fetchTodos();
    }
    this.fetchTags();
    this.checkAndUpdateExpiredTodos();
  }

  aboutToAppear() {
    this.fetchTags();
    this.fetchNotes();
    this.fetchTodos();
    this.checkAndUpdateExpiredTodos();
  }

  // ── 笔记数据 ──
  async fetchNotes() {
    try {
      const data = await request<Note[]>('/notes/', 'GET');
      this.notes = data ?? [];
    } catch (e) {
      console.error('加载笔记失败', JSON.stringify(e));
    }
  }

  // ── 笔记删除逻辑 ──
  async deleteNote(id: number) {
    try {
      // 调用后端接口
      await request<object>(`/notes/${id}`, 'DELETE');
      promptAction.showToast({ message: '笔记已删除' });
      // 重新拉取数据以刷新 UI
      await this.fetchNotes();
    } catch (e) {
      console.error('删除笔记失败', JSON.stringify(e));
      promptAction.showToast({ message: '删除失败' });
    }
  }


  async fetchTags() {
    try {
      const data = await request<Tag[]>('/tags/', 'GET');
      this.tags = data ?? [];
    } catch (e) {
      console.error('加载标签失败', JSON.stringify(e));
    }
  }

  tagNameById(tagId?: number): string {
    if (typeof tagId !== 'number') return '';
    const found = this.tags.find(t => t.id === tagId);
    return found ? found.name : '';
  }

  // 按标签 ID 获取笔记
  async fetchNotesByTag(tagId: number) {
    try {
      // 假设你的后端接口支持 ?tag_id= 过滤，或者使用 search 接口
      const data = await request<Note[]>(`/notes/?tag_id=${tagId}`, 'GET');
      this.notes = data ?? [];
    } catch (e) {
      promptAction.showToast({ message: '获取分类笔记失败' });
    }
  }

  async fetchTodos() {
    try {
      const params: string[] = [];
      if (this.statusFilter !== 'all') params.push(`status=${this.statusFilter}`);
      if (this.priorityFilter !== 'all') params.push(`priority=${this.priorityFilter}`);

      const qs = params.length > 0 ? '?' + params.join('&') : '';
      const data = await request<Todo[]>(`/todos/${qs}`, 'GET');

      // --- 修改开始：增加排序逻辑 ---
      let rawList = data ?? [];

      // 排序规则：
      // 1. 已完成的任务（completed）永远排在最后
      // 2. 其余任务按截止时间（deadline）正序排列（越近越靠前）
      // 3. 没有截止时间的任务排在有截止时间的任务后面
      this.todos = rawList.sort((a: Todo, b: Todo) => {
        // 首先处理“已完成”状态的置底
        if (a.status === 'completed' && b.status !== 'completed') return 1;
        if (a.status !== 'completed' && b.status === 'completed') return -1;

        // 其次处理时间排序
        if (!a.deadline && !b.deadline) return 0;
        if (!a.deadline) return 1;
        if (!b.deadline) return -1;

        const timeA = new Date(a.deadline).getTime();
        const timeB = new Date(b.deadline).getTime();
        return timeA - timeB;
      });
      // --- 修改结束 ---

      // this.todos = data ?? [];
      // this.checkAndUpdateExpiredTodos();
    } catch (e) {
      console.error('加载待办失败', JSON.stringify(e));
    }
  }

  async createTodo() {
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
      promptAction.showToast({ message: '添加失败' });
    } finally {
      this.isSubmittingTodo = false;
    }
  }

  async setTodoStatus(id: number, status: TodoStatus) {
    try {
      const payload: TodoUpdateRequest = { status };
      await request<Todo>(`/todos/${id}`, 'PUT', payload);
      await this.fetchTodos();
    } catch (e) {
      promptAction.showToast({ message: '更新状态失败' });
    }
  }

  async setTodoPriority(id: number, priority: string) {
    // 1. 立即更新本地状态数组，通过 map 返回新数组来触发 UI 刷新
    const nextTodos = this.todos.map((t: Todo): Todo => {
      if (t.id === id) {
        return {
          id: t.id,
          title: t.title,
          status: t.status,
          priority: priority as TodoPriority,
          deadline: t.deadline,
          note_id: t.note_id
        } as Todo;
      }
      return t;
    });

    this.todos = nextTodos;

    try {
      // 2. 发送请求同步到后端
      const payload: Record<string, string> = { 'priority': priority };
      await request<Todo>(`/todos/${id}`, 'PUT', payload);

      // 3. 后台静默刷新，确保与数据库数据一致（如排序逻辑）
      await this.fetchTodos();
      promptAction.showToast({ message: '优先级已更新' });
    } catch (e) {
      promptAction.showToast({ message: '更新优先级失败' });
      // 失败时可以考虑重新 fetchTodos 以回滚本地状态
      await this.fetchTodos();
    }
  }

  async deleteTodo(id: number) {
    try {
      await request<object>(`/todos/${id}`, 'DELETE');
      await this.fetchTodos();
      promptAction.showToast({ message: '已删除' });
    } catch (e) {
      promptAction.showToast({ message: '删除失败' });
    }
  }

  // 自动检查并更新过期任务
  // 自动检查并更新过期任务（推荐最终版）
  async checkAndUpdateExpiredTodos() {
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

      // 等待所有更新请求完成
      if (updatePromises.length > 0) {
        await Promise.all(updatePromises);
        promptAction.showToast({ message: `已自动更新 ${updatePromises.length} 个延期任务` });
      }

      // 最后统一刷新一次列表
      await this.fetchTodos();
    } catch (e) {
      console.error('自动更新延期任务失败', e);
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

  // 获取回退状态的辅助方法
  getFallbackStatus(deadline?: string): TodoStatus {
    if (!deadline) return 'pending';
    const now = new Date().getTime();
    const isOverdue = new Date(deadline).getTime() < now;
    return isOverdue ? 'delayed' : 'pending';
  }

  // 获取回退文字的辅助方法
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



  // ── 主体布局 ──
  build() {
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
        // 切到任务 Tab 时刷新
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
    .backgroundColor('#F9F8F4')
  }

  // ── 自定义 TabBar ──
  @Builder TabBuilder(title: string, index: number, icon: string) {
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

  // ── Tab1：笔记草原 ──
  @Builder MeadowHeader() {
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
  NotesTab() {
    // 必须用 Stack 包裹，才能让按钮浮在列表上面
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 1. 头部标题栏
        this.MeadowHeader()

        // 2. 分类横排列表
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

        // 3. 笔记列表
        if (this.notes.length === 0) {
          this.EmptyState() // 确保方法名对应上
        } else {
          List({ space: 16 }) {
            // ForEach(this.notes, (note: Note) => {
            //   ListItem() {
            //     this.NoteCard(note)
            //   }
            //   .onClick(() => {
            //     router.pushUrl({ url: 'pages/NoteEdit', params: { id: note.id } });
            //   })
            // }, (item: Note) => item.id.toString())
            ForEach(this.notes, (note: Note) => {
              ListItem() {
                this.NoteCard(note)
              }
              // 注入滑动操作
              .swipeAction({
                end: {
                  builder: () => { this.noteSwipeBuilder(note.id) },
                  onAction: () => {
                    // 这里可以处理滑动到最右侧触发的动作，目前已在按钮 onClick 处理
                  },
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

      // 4. 右下角悬浮按钮 🦙
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
    .backgroundColor('#F9F8F4')
  }

  @Builder
  noteSwipeBuilder(id: number) {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(20)
          .fontColor(['#FFFFFF'])
      }
      .width(60)
      .height(60)
      .backgroundColor('#C0392B') // 红色代表危险操作
      .type(ButtonType.Circle)
      .margin({ left: 15, right: 15 })
      .onClick(() => {
        this.deleteNote(id);
      })
    }
    .justifyContent(FlexAlign.Center)
    .height('100%')
  }

  // ── Tab2：任务 Tab（双维度筛选 + 列表 + 加号跳转）──
  @Builder PeakSection() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 标题（保留你原来的风格）
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

        // 第一行：任务进度筛选
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

        // 第二行：重要紧急程度筛选
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

        // 待办列表
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
            }, (todo: Todo) => todo.id.toString() +  "_" + todo.priority)
          }
          .layoutWeight(1)
          .padding({ left: 20, right: 20, top: 12, bottom: 20 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F9F8F4')

      // 右下角 + 按钮 → 跳转到 TodoBoard 页面
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
    .backgroundColor('#F9F8F4')
  }

  // ── Tab3：行囊 ──
  @Builder PackSection() {
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
        this.PackItem('🎨 主题装扮', () => {})
        this.PackItem('⚙️ 设置中心', () => {})
      }
      .backgroundColor('#FFF')
      .borderRadius(16)
      .margin({ left: 20, right: 20 })
      .shadow({ radius: 8, color: '#064A3933', offsetY: 2 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder PackItem(title: string, onClick: () => void) {
    Row() {
      Text(title).fontSize(16).fontColor('#4A3933')
      Blank()
      Text('→').fontColor('#D2C4B0')
    }
    .width('100%')
    .padding(18)
    .onClick(onClick)
  }

  // ── 待办卡片 ──
  @Builder TodoCard(todo: Todo) {
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
        // --- 动态状态切换按钮组 ---
        Row({ space: 8 }) {
          // 情况 A：任务当前是“待处理”或“已延期”
          if (todo.status === 'pending' || todo.status === 'delayed') {
            // 按钮：变为“已完成”
            Text('已完成')
              .fontSize(12)
              .fontColor('#FFF')
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor('#705C53')
              .borderRadius(10)
              .onClick(() => this.setTodoStatus(todo.id, 'completed'))

            // 当前状态展示（置灰且不可点击，实现禁止待处理和已延期互转）
            Text(todo.status === 'pending' ? '待处理' : '已延期')
              .fontSize(12)
              .fontColor('#A89982')
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor('#EFEBE9')
              .borderRadius(10)
              .opacity(0.6)
          }
          // 情况 B：任务当前是“已完成”
          else if (todo.status === 'completed') {
            // “已完成”状态高亮
            Text('已完成')
              .fontSize(12)
              .fontColor('#A89982')
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor('#EFEBE9')
              .borderRadius(10)
              .opacity(0.6)

            Text(this.getFallbackLabel(todo.deadline)) // 直接调用方法
              .fontSize(12)
              .fontColor('#FFF')
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor('#705C53')
              .borderRadius(10)
              .onClick(() => {
                // 直接调用方法获取状态
                const status = this.getFallbackStatus(todo.deadline);
                this.setTodoStatus(todo.id, status);
              })
          }
        }

        Blank()

        // --- 快捷优先级圆点（点击即刻变色） ---
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

  // ── 笔记卡片 ──
  @Builder NoteCard(note: Note) {
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
          .margin({ top: 4, bottom: 4 }) // 增加适量间距让卡片更美观
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

  // ── 空状态 ──
  @Builder EmptyState() {
    Column() {
      Text('🦙').fontSize(60)
      Text('草坪空荡荡，快去采撷灵感吧').fontSize(14).fontColor('#A89982').margin({ top: 10 })
    }.layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
  }

}

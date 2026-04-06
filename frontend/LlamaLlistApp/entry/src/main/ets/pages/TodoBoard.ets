import { request } from '../common/network/httpClient';
import { Todo, TodoStatus } from '../models/Todo';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct TodoBoard {
  @State todos: Todo[] = [];
  @State titleInput: string = '';
  @State deadlineInput: string = '';
  @State statusFilter: TodoStatus | 'all' = 'all';
  @State isSubmitting: boolean = false;

  aboutToAppear() {
    this.fetchTodos();
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button('返回').onClick(() => router.back())
        Blank()
        Text('待办看板').fontSize(20).fontWeight(FontWeight.Medium)
        Blank()
      }
      .width('100%')
      .padding(16)

      Row({ space: 8 }) {
        Button('全部')
          .backgroundColor(this.statusFilter === 'all' ? '#333' : '#EEE')
          .fontColor(this.statusFilter === 'all' ? '#FFF' : '#333')
          .onClick(() => { this.statusFilter = 'all'; this.fetchTodos(); })
        Button('待处理')
          .backgroundColor(this.statusFilter === 'pending' ? '#333' : '#EEE')
          .fontColor(this.statusFilter === 'pending' ? '#FFF' : '#333')
          .onClick(() => { this.statusFilter = 'pending'; this.fetchTodos(); })
        Button('已完成')
          .backgroundColor(this.statusFilter === 'completed' ? '#333' : '#EEE')
          .fontColor(this.statusFilter === 'completed' ? '#FFF' : '#333')
          .onClick(() => { this.statusFilter = 'completed'; this.fetchTodos(); })
        Button('已延期')
          .backgroundColor(this.statusFilter === 'delayed' ? '#333' : '#EEE')
          .fontColor(this.statusFilter === 'delayed' ? '#FFF' : '#333')
          .onClick(() => { this.statusFilter = 'delayed'; this.fetchTodos(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Column({ space: 8 }) {
        TextInput({ placeholder: '新增待办标题（必填）', text: this.titleInput })
          .onChange((v: string) => this.titleInput = v)
        TextInput({ placeholder: '截止日期（可选，YYYY-MM-DD）', text: this.deadlineInput })
          .onChange((v: string) => this.deadlineInput = v)
        Button('添加待办')
          .enabled(!this.isSubmitting)
          .onClick(() => this.createTodo())
      }
      .padding({ left: 16, right: 16 })
      .width('100%')

      if (this.todos.length === 0) {
        Column() {
          Text('暂无待办').fontSize(16).fontColor('#999')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.todos, (todo: Todo) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Text(todo.title).fontSize(16).maxLines(2).layoutWeight(1)
                  Button('删除')
                    .backgroundColor('#FDECEC')
                    .fontColor('#D93025')
                    .onClick(() => this.deleteTodo(todo.id))
                }
                if (todo.deadline) {
                  Text(`截止：${todo.deadline}`).fontSize(12).fontColor('#999')
                }
                Row({ space: 8 }) {
                  Button('待处理')
                    .backgroundColor(todo.status === 'pending' ? '#333' : '#EEE')
                    .fontColor(todo.status === 'pending' ? '#FFF' : '#333')
                    .onClick(() => this.setStatus(todo.id, 'pending'))
                  Button('已完成')
                    .backgroundColor(todo.status === 'completed' ? '#333' : '#EEE')
                    .fontColor(todo.status === 'completed' ? '#FFF' : '#333')
                    .onClick(() => this.setStatus(todo.id, 'completed'))
                  Button('已延期')
                    .backgroundColor(todo.status === 'delayed' ? '#333' : '#EEE')
                    .fontColor(todo.status === 'delayed' ? '#FFF' : '#333')
                    .onClick(() => this.setStatus(todo.id, 'delayed'))
                }.flexWrap(FlexWrap.Wrap)
              }
              .padding(12)
              .backgroundColor('#F5F5F5')
              .borderRadius(12)
            }
          }, (todo: Todo) => todo.id.toString())
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF')
  }

  async fetchTodos() {
    try {
      const qs = this.statusFilter === 'all' ? '' : `?status=${this.statusFilter}`;
      const data = await request<Todo[]>(`/todos/${qs}`, 'GET');
      this.todos = data;
    } catch (e) {
      promptAction.showToast({ message: '加载待办失败' });
      console.error('加载待办失败', JSON.stringify(e));
    }
  }

  async createTodo() {
    const title = this.titleInput.trim();
    if (!title) {
      promptAction.showToast({ message: '待办标题不能为空' });
      return;
    }
    let deadlineIso: string | undefined = undefined;
    const d = this.deadlineInput.trim();
    if (d) {
      const parsed = new Date(d);
      if (!Number.isNaN(parsed.getTime())) {
        deadlineIso = parsed.toISOString();
      } else {
        promptAction.showToast({ message: '截止日期格式不正确' });
        return;
      }
    }

    this.isSubmitting = true;
    try {
      await request<Todo>('/todos/', 'POST', { title, deadline: deadlineIso });
      this.titleInput = '';
      this.deadlineInput = '';
      await this.fetchTodos();
      promptAction.showToast({ message: '添加成功' });
    } catch (e) {
      promptAction.showToast({ message: '添加失败' });
      console.error('添加待办失败', JSON.stringify(e));
    } finally {
      this.isSubmitting = false;
    }
  }

  async setStatus(id: number, status: TodoStatus) {
    try {
      await request<Todo>(`/todos/${id}`, 'PUT', { status });
      await this.fetchTodos();
    } catch (e) {
      promptAction.showToast({ message: '更新状态失败' });
      console.error('更新待办失败', JSON.stringify(e));
    }
  }

  async deleteTodo(id: number) {
    try {
      await request<object>(`/todos/${id}`, 'DELETE');
      await this.fetchTodos();
      promptAction.showToast({ message: '删除成功' });
    } catch (e) {
      promptAction.showToast({ message: '删除失败' });
      console.error('删除待办失败', JSON.stringify(e));
    }
  }
}

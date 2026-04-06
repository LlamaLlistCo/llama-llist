export type TodoStatus = 'pending' | 'completed' | 'delayed';

export interface Todo {
  id: number;
  title: string;
  status: TodoStatus;
  deadline?: string;
  note_id?: number;
}

export type TodoStatus = 'pending' | 'completed' | 'delayed';
export type TodoPriority = 'important_urgent' | 'important_not_urgent' | 'not_important_urgent' | 'not_important_not_urgent';

export interface Todo {
  id: number;
  title: string;
  status: TodoStatus;
  priority: TodoPriority;
  deadline?: string;
  note_id?: number;
}

export interface PriorityConfig {
  label: string;
  color: string;
  bg: string;
  icon: string;
}

export function getPriorityConfig(priority: TodoPriority): PriorityConfig {
  if (priority === 'important_urgent') {
    return { label: '重要且紧急', color: '#C0392B', bg: '#FDECEC', icon: '🔴' };
  } else if (priority === 'important_not_urgent') {
    return { label: '重要不紧急', color: '#E67E22', bg: '#FEF3E2', icon: '🟠' };
  } else if (priority === 'not_important_urgent') {
    return { label: '不重要紧急', color: '#2980B9', bg: '#EBF5FB', icon: '🔵' };
  } else {
    return { label: '不重要不紧急', color: '#A89982', bg: '#EFEBE9', icon: '⚪' };
  }
}
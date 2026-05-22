export interface Note {
  id: number;
  title: string;
  content: string;
  summary?: string;
  view_type?: string;
  image_paths?: string;
  tag_id?: number;
  created_at: string;
  updated_at: string;
}

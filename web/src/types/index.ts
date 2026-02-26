export interface User {
  id: string;
  email: string;
  created_at: string;
  updated_at: string;
}

export interface Notebook {
  id: string;
  user_id: string;
  title: string;
  created_at: string;
  updated_at: string;
  deleted_at?: string;
}

export interface Note {
  id: string;
  notebook_id: string;
  user_id: string;
  content: Record<string, unknown>;
  plain_text: string;
  is_todo: boolean;
  is_done: boolean;
  reminder_at?: string;
  version: number;
  created_at: string;
  updated_at: string;
  deleted_at?: string;
  tags?: Tag[];
}

export interface Tag {
  id: string;
  user_id: string;
  name: string;
  color?: string;
  created_at: string;
  updated_at: string;
}

export interface Image {
  id: string;
  note_id: string;
  filename: string;
  mime_type: string;
  storage_key: string;
  size: number;
  created_at: string;
}

export interface AuthResponse {
  user: User;
  access_token: string;
  refresh_token: string;
}

export interface CreateNoteRequest {
  content: Record<string, unknown>;
  plain_text?: string;
  is_todo?: boolean;
  reminder_at?: string;
  tag_ids?: string[];
}

export interface UpdateNoteRequest {
  content?: Record<string, unknown>;
  plain_text?: string;
  is_todo?: boolean;
  is_done?: boolean;
  reminder_at?: string;
  tag_ids?: string[];
}

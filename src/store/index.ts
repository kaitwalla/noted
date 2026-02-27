import { create } from 'zustand';
import { api } from '../api/client';
import type { User, Notebook, Note, Tag } from '../types';

interface AppState {
  // Auth
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;

  // Notebooks
  notebooks: Notebook[];
  selectedNotebookId: string | null;

  // Notes
  notes: Note[];
  selectedNoteId: string | null;

  // Tags
  tags: Tag[];

  // Actions
  setUser: (user: User | null) => void;
  setLoading: (loading: boolean) => void;
  logout: () => void;

  // Notebook actions
  fetchNotebooks: () => Promise<void>;
  selectNotebook: (id: string | null) => void;
  addNotebook: (title: string) => Promise<Notebook>;
  removeNotebook: (id: string) => Promise<void>;

  // Note actions
  fetchNotes: (notebookId: string) => Promise<void>;
  selectNote: (id: string | null) => void;
  addNote: (notebookId: string, content: Record<string, unknown>, plainText: string, isTodo?: boolean, tagIds?: string[], reminderAt?: string) => Promise<Note>;
  updateNote: (noteId: string, updates: Partial<Note>) => Promise<void>;
  toggleNoteDone: (noteId: string) => Promise<void>;
  removeNote: (noteId: string) => Promise<void>;

  // Tag actions
  fetchTags: () => Promise<void>;
  addTag: (name: string, color?: string) => Promise<Tag>;
  removeTag: (id: string) => Promise<void>;
}

export const useStore = create<AppState>((set, get) => ({
  // Initial state
  user: null,
  isAuthenticated: api.isAuthenticated(),
  isLoading: true,
  notebooks: [],
  selectedNotebookId: null,
  notes: [],
  selectedNoteId: null,
  tags: [],

  // Auth actions
  setUser: (user) => set({ user, isAuthenticated: !!user }),
  setLoading: (isLoading) => set({ isLoading }),
  logout: () => {
    api.clearTokens();
    set({
      user: null,
      isAuthenticated: false,
      notebooks: [],
      notes: [],
      tags: [],
      selectedNotebookId: null,
      selectedNoteId: null,
    });
  },

  // Notebook actions
  fetchNotebooks: async () => {
    const notebooks = await api.getNotebooks();
    const currentSelected = get().selectedNotebookId;
    // Auto-select first notebook if none is selected
    const selectedNotebookId = currentSelected || (notebooks.length > 0 ? notebooks[0].id : null);
    set({ notebooks, selectedNotebookId });
    // Fetch notes for auto-selected notebook
    if (selectedNotebookId && !currentSelected) {
      get().fetchNotes(selectedNotebookId).catch((error) => {
        console.error('Failed to fetch notes:', error);
      });
    }
  },

  selectNotebook: (id) => {
    set({ selectedNotebookId: id, notes: [], selectedNoteId: null });
    if (id) {
      get().fetchNotes(id).catch((error) => {
        console.error('Failed to fetch notes:', error);
      });
    }
  },

  addNotebook: async (title) => {
    const notebook = await api.createNotebook(title);
    set((state) => ({ notebooks: [notebook, ...state.notebooks] }));
    return notebook;
  },

  removeNotebook: async (id) => {
    await api.deleteNotebook(id);
    set((state) => ({
      notebooks: state.notebooks.filter((n) => n.id !== id),
      selectedNotebookId: state.selectedNotebookId === id ? null : state.selectedNotebookId,
    }));
  },

  // Note actions
  fetchNotes: async (notebookId) => {
    const notes = await api.getNotes(notebookId);
    set({ notes });
  },

  selectNote: (id) => set({ selectedNoteId: id }),

  addNote: async (notebookId, content, plainText, isTodo = false, tagIds = [], reminderAt) => {
    const note = await api.createNote(notebookId, {
      content,
      plain_text: plainText,
      is_todo: isTodo,
      tag_ids: tagIds,
      reminder_at: reminderAt,
    });
    set((state) => ({ notes: [...state.notes, note] }));
    return note;
  },

  updateNote: async (noteId, updates) => {
    const note = await api.updateNote(noteId, {
      content: updates.content,
      plain_text: updates.plain_text,
      is_todo: updates.is_todo,
      is_done: updates.is_done,
      tag_ids: updates.tag_ids,
      reminder_at: updates.reminder_at,
    });
    set((state) => ({
      notes: state.notes.map((n) => (n.id === noteId ? note : n)),
    }));
  },

  toggleNoteDone: async (noteId) => {
    const note = get().notes.find((n) => n.id === noteId);
    if (note) {
      const updated = await api.updateNote(noteId, { is_done: !note.is_done });
      set((state) => ({
        notes: state.notes.map((n) => (n.id === noteId ? updated : n)),
      }));
    }
  },

  removeNote: async (noteId) => {
    await api.deleteNote(noteId);
    set((state) => ({
      notes: state.notes.filter((n) => n.id !== noteId),
      selectedNoteId: state.selectedNoteId === noteId ? null : state.selectedNoteId,
    }));
  },

  // Tag actions
  fetchTags: async () => {
    const tags = await api.getTags();
    set({ tags });
  },

  addTag: async (name, color) => {
    const tag = await api.createTag(name, color);
    set((state) => ({ tags: [...state.tags, tag] }));
    return tag;
  },

  removeTag: async (id) => {
    await api.deleteTag(id);
    set((state) => ({ tags: state.tags.filter((t) => t.id !== id) }));
  },
}));

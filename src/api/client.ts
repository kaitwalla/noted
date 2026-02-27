import axios, { type AxiosInstance, type InternalAxiosRequestConfig } from 'axios';
import type { AuthResponse, Notebook, Note, Tag, User, CreateNoteRequest, UpdateNoteRequest, Image } from '../types';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080/api';

class ApiClient {
  private client: AxiosInstance;
  private accessToken: string | null = null;
  private refreshToken: string | null = null;

  constructor() {
    this.client = axios.create({
      baseURL: API_URL,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Load tokens from localStorage
    this.accessToken = localStorage.getItem('accessToken');
    this.refreshToken = localStorage.getItem('refreshToken');

    // Add auth header to requests
    this.client.interceptors.request.use((config: InternalAxiosRequestConfig) => {
      if (this.accessToken && config.headers) {
        config.headers.Authorization = `Bearer ${this.accessToken}`;
      }
      return config;
    });

    // Handle 401 responses
    this.client.interceptors.response.use(
      (response) => response,
      async (error) => {
        const originalRequest = error.config;
        if (error.response?.status === 401 && !originalRequest._retry && this.refreshToken) {
          originalRequest._retry = true;
          try {
            const response = await this.refresh();
            this.setTokens(response.access_token, response.refresh_token);
            return this.client(originalRequest);
          } catch {
            this.clearTokens();
            window.location.href = '/login';
          }
        }
        return Promise.reject(error);
      }
    );
  }

  setTokens(accessToken: string, refreshToken: string) {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    localStorage.setItem('accessToken', accessToken);
    localStorage.setItem('refreshToken', refreshToken);
  }

  clearTokens() {
    this.accessToken = null;
    this.refreshToken = null;
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
  }

  isAuthenticated(): boolean {
    return !!this.accessToken;
  }

  // Auth
  async register(email: string, password: string): Promise<AuthResponse> {
    const response = await this.client.post<AuthResponse>('/auth/register', { email, password });
    return response.data;
  }

  async login(email: string, password: string): Promise<AuthResponse> {
    const response = await this.client.post<AuthResponse>('/auth/login', { email, password });
    return response.data;
  }

  async refresh(): Promise<AuthResponse> {
    // Use axios directly instead of this.client to avoid interceptor loop
    // when refresh endpoint returns 401
    const response = await axios.post<AuthResponse>(`${API_URL}/auth/refresh`, {
      refresh_token: this.refreshToken,
    }, {
      headers: { 'Content-Type': 'application/json' },
    });
    return response.data;
  }

  async getMe(): Promise<User> {
    const response = await this.client.get<User>('/auth/me');
    return response.data;
  }

  // Notebooks
  async getNotebooks(): Promise<Notebook[]> {
    const response = await this.client.get<Notebook[]>('/notebooks');
    return response.data;
  }

  async createNotebook(title: string): Promise<Notebook> {
    const response = await this.client.post<Notebook>('/notebooks', { title });
    return response.data;
  }

  async updateNotebook(id: string, title: string): Promise<Notebook> {
    const response = await this.client.put<Notebook>(`/notebooks/${id}`, { title });
    return response.data;
  }

  async deleteNotebook(id: string): Promise<void> {
    await this.client.delete(`/notebooks/${id}`);
  }

  // Notes
  async getNotes(notebookId: string): Promise<Note[]> {
    const response = await this.client.get<Note[]>(`/notebooks/${notebookId}/notes`);
    return response.data;
  }

  async createNote(notebookId: string, data: CreateNoteRequest): Promise<Note> {
    const response = await this.client.post<Note>(`/notebooks/${notebookId}/notes`, data);
    return response.data;
  }

  async updateNote(noteId: string, data: UpdateNoteRequest): Promise<Note> {
    const response = await this.client.put<Note>(`/notes/${noteId}`, data);
    return response.data;
  }

  async deleteNote(noteId: string): Promise<void> {
    await this.client.delete(`/notes/${noteId}`);
  }

  // Tags
  async getTags(): Promise<Tag[]> {
    const response = await this.client.get<Tag[]>('/tags');
    return response.data;
  }

  async createTag(name: string, color?: string): Promise<Tag> {
    const response = await this.client.post<Tag>('/tags', { name, color });
    return response.data;
  }

  async deleteTag(id: string): Promise<void> {
    await this.client.delete(`/tags/${id}`);
  }

  // Search
  async search(query: string): Promise<Note[]> {
    const response = await this.client.get<Note[]>('/search', { params: { q: query } });
    return response.data;
  }

  // Images
  async uploadImage(noteId: string, file: File): Promise<Image> {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('note_id', noteId);
    const response = await this.client.post<Image>('/images', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return response.data;
  }

  async getImageSignedUrl(imageId: string): Promise<string> {
    const response = await this.client.get<{ url: string }>(`/images/${imageId}/url`);
    return response.data.url;
  }

  async getNoteImages(noteId: string): Promise<Image[]> {
    const response = await this.client.get<Image[]>(`/notes/${noteId}/images`);
    return response.data;
  }

  getImageUrl(imageId: string): string {
    return `${API_URL}/images/${imageId}`;
  }
}

export const api = new ApiClient();

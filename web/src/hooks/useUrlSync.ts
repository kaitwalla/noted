import { useEffect, useRef } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useStore } from '../store';

// Format a date as YYYYMMDD-HHmmss for URL
export function formatTimestamp(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  const seconds = String(d.getSeconds()).padStart(2, '0');
  return `${year}${month}${day}-${hours}${minutes}${seconds}`;
}

// Parse a timestamp from URL back to date components
export function parseTimestamp(timestamp: string): Date | null {
  // Format: YYYYMMDD-HHmmss
  const match = timestamp.match(/^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})$/);
  if (!match) return null;
  const [, year, month, day, hours, minutes, seconds] = match;
  return new Date(
    parseInt(year),
    parseInt(month) - 1,
    parseInt(day),
    parseInt(hours),
    parseInt(minutes),
    parseInt(seconds)
  );
}

// Hook to sync URL with selected notebook/note
export function useUrlSync() {
  const navigate = useNavigate();
  const { notebookId, timestamp } = useParams<{ notebookId?: string; timestamp?: string }>();
  const {
    notebooks,
    selectedNotebookId,
    selectedNoteId,
    notes,
    selectNotebookById,
    selectNoteByTimestamp,
  } = useStore();

  const initialSyncDone = useRef(false);
  const urlSyncDone = useRef(false);

  // Sync URL params to state only on initial load
  useEffect(() => {
    if (notebooks.length === 0 || urlSyncDone.current) return;

    if (notebookId && notebookId !== selectedNotebookId) {
      selectNotebookById(notebookId);
    }
    urlSyncDone.current = true;
  }, [notebookId, notebooks, selectedNotebookId, selectNotebookById]);

  // Sync timestamp to selected note after notes are loaded
  useEffect(() => {
    if (timestamp && notes.length > 0 && !initialSyncDone.current) {
      selectNoteByTimestamp(timestamp);
      initialSyncDone.current = true;
    }
  }, [timestamp, notes, selectNoteByTimestamp]);

  // Sync state changes to URL
  useEffect(() => {
    if (!selectedNotebookId) return;

    const selectedNote = notes.find((n) => n.id === selectedNoteId);

    if (selectedNote) {
      const ts = formatTimestamp(selectedNote.created_at);
      const newPath = `/notebooks/${selectedNotebookId}/${ts}`;
      if (window.location.pathname !== newPath) {
        navigate(newPath, { replace: true });
      }
    } else if (selectedNotebookId) {
      const newPath = `/notebooks/${selectedNotebookId}`;
      if (window.location.pathname !== newPath) {
        navigate(newPath, { replace: true });
      }
    }
  }, [selectedNotebookId, selectedNoteId, notes, navigate]);
}

// Get the public note URL for sharing
export function getPublicNoteUrl(noteId: string): string {
  const baseUrl = window.location.origin;
  return `${baseUrl}/n/${noteId}`;
}

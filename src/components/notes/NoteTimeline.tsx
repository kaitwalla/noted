import { useEffect } from 'react';
import { format, isToday, isYesterday } from 'date-fns';
import { useStore } from '../../store';
import { NoteBubble } from './NoteBubble';
import { NoteEditor } from './NoteEditor';
import type { Note } from '../../types';

export function NoteTimeline() {
  const { notes, selectedNotebookId, fetchNotes } = useStore();

  useEffect(() => {
    if (selectedNotebookId) {
      fetchNotes(selectedNotebookId);
    }
  }, [selectedNotebookId, fetchNotes]);

  const groupedNotes = groupNotesByDate(notes);

  if (!selectedNotebookId) {
    return (
      <div className="note-timeline empty-state">
        <div className="empty-message">
          <h3>Select a notebook</h3>
          <p>Choose a notebook from the sidebar to view and add notes</p>
        </div>
      </div>
    );
  }

  return (
    <div className="note-timeline">
      <div className="notes-container">
        {Object.entries(groupedNotes)
          .sort(([a], [b]) => b.localeCompare(a)) // newest date first
          .map(([date, dateNotes]) => (
          <div key={date} className="date-group">
            <div className="date-divider">
              <span>{formatDateLabel(date)}</span>
            </div>
            {dateNotes.map((note) => (
              <NoteBubble key={note.id} note={note} />
            ))}
          </div>
        ))}
        {notes.length === 0 && (
          <div className="empty-notes">
            <p>No notes yet. Start typing below to add your first note.</p>
          </div>
        )}
      </div>
      <NoteEditor />
    </div>
  );
}

function groupNotesByDate(notes: Note[]) {
  const groups: Record<string, Note[]> = {};

  notes.forEach((note: Note) => {
    const date = format(new Date(note.created_at), 'yyyy-MM-dd');
    if (!groups[date]) {
      groups[date] = [];
    }
    groups[date].push(note);
  });

  return groups;
}

function formatDateLabel(dateStr: string): string {
  // Parse as local date to avoid timezone shift
  // new Date('yyyy-MM-dd') parses as UTC, which can show wrong day in negative UTC offsets
  const [year, month, day] = dateStr.split('-').map(Number);
  const date = new Date(year, month - 1, day);
  if (isToday(date)) return 'Today';
  if (isYesterday(date)) return 'Yesterday';
  return format(date, 'MMMM d, yyyy');
}

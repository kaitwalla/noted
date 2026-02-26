import { useState } from 'react';
import { format, isValid } from 'date-fns';
import { Check, Circle, Trash2, Edit2 } from 'lucide-react';
import { useStore } from '../../store';
import type { Note } from '../../types';
import { NoteEditModal } from './NoteEditModal';

interface NoteBubbleProps {
  note: Note;
}

export function NoteBubble({ note }: NoteBubbleProps) {
  const [isEditing, setIsEditing] = useState(false);
  const { toggleNoteDone, removeNote } = useStore();

  const handleToggle = () => {
    if (note.is_todo) {
      toggleNoteDone(note.id);
    }
  };

  const handleDelete = () => {
    if (confirm('Delete this note?')) {
      removeNote(note.id);
    }
  };

  interface TiptapNode {
    type?: string;
    content?: TiptapNode[];
    text?: string;
    attrs?: { src?: string; alt?: string };
  }

  const renderContent = () => {
    // Try to extract content from the Tiptap JSON
    if (note.content && typeof note.content === 'object') {
      const content = note.content as { content?: TiptapNode[] };
      const elements: React.ReactNode[] = [];
      let key = 0;

      const extractNodes = (nodes: TiptapNode[] | undefined): void => {
        if (!nodes) return;
        for (const node of nodes) {
          if (node.type === 'image' && node.attrs?.src) {
            elements.push(
              <img key={key++} src={node.attrs.src} alt={node.attrs.alt || ''} />
            );
          } else if (node.text) {
            elements.push(<span key={key++}>{node.text}</span>);
          } else if (node.content) {
            extractNodes(node.content);
          }
          if (node.type === 'paragraph' && elements.length > 0) {
            elements.push(<br key={key++} />);
          }
        }
      };

      extractNodes(content.content);
      if (elements.length > 0) {
        // Remove trailing <br>
        if (elements[elements.length - 1]?.toString().includes('br')) {
          elements.pop();
        }
        return <>{elements}</>;
      }
    }
    return note.plain_text || '';
  };

  return (
    <>
      <div className={`note-bubble ${note.is_todo ? 'is-todo' : ''} ${note.is_done ? 'is-done' : ''}`}>
        {note.is_todo && (
          <button className="todo-checkbox" onClick={handleToggle}>
            {note.is_done ? <Check size={16} /> : <Circle size={16} />}
          </button>
        )}
        <div className="note-content">
          <p className={note.is_done ? 'strikethrough' : ''}>{renderContent()}</p>
          {note.tags && note.tags.length > 0 && (
            <div className="note-tags">
              {note.tags.map((tag) => (
                <span
                  key={tag.id}
                  className="tag"
                  style={{ backgroundColor: tag.color || '#6366f1' }}
                >
                  {tag.name}
                </span>
              ))}
            </div>
          )}
        </div>
        <div className="note-meta">
          <span className="note-time">
            {note.created_at && isValid(new Date(note.created_at))
              ? format(new Date(note.created_at), 'h:mm a')
              : ''}
          </span>
          <div className="note-actions">
            <button onClick={() => setIsEditing(true)} title="Edit">
              <Edit2 size={14} />
            </button>
            <button onClick={handleDelete} title="Delete">
              <Trash2 size={14} />
            </button>
          </div>
        </div>
      </div>

      {isEditing && (
        <NoteEditModal note={note} onClose={() => setIsEditing(false)} />
      )}
    </>
  );
}

import { useState, useEffect } from 'react';
import { format, isValid } from 'date-fns';
import { Check, Circle, Trash2, Edit2, Globe, GlobeLock, Link2 } from 'lucide-react';
import { useStore } from '../../store';
import { api } from '../../api/client';
import type { Note } from '../../types';
import { NoteEditModal } from './NoteEditModal';
import { LinkPreviewCard } from './LinkPreviewCard';
import { getPublicNoteUrl } from '../../hooks/useUrlSync';

interface NoteBubbleProps {
  note: Note;
}

export function NoteBubble({ note }: NoteBubbleProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [images, setImages] = useState<Array<{ id: string; url: string }>>([]);
  const [copied, setCopied] = useState(false);
  const { toggleNoteDone, toggleNotePublic, removeNote } = useStore();

  // Fetch images for this note (re-fetch when note object changes)
  useEffect(() => {
    api.getNoteImages(note.id).then((noteImages) => {
      setImages(noteImages.map((img) => ({ id: img.id, url: img.url })));
    }).catch(() => {
      setImages([]);
    });
  }, [note]);

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

  const handleTogglePublic = () => {
    toggleNotePublic(note.id);
  };

  const COPY_FEEDBACK_DURATION_MS = 2000;

  const handleCopyLink = async () => {
    const url = getPublicNoteUrl(note.id);
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), COPY_FEEDBACK_DURATION_MS);
    } catch {
      // Fallback for older browsers
      const textArea = document.createElement('textarea');
      textArea.value = url;
      textArea.style.position = 'fixed';
      textArea.style.left = '-9999px';
      document.body.appendChild(textArea);
      textArea.select();
      const success = document.execCommand('copy');
      document.body.removeChild(textArea);
      if (success) {
        setCopied(true);
        setTimeout(() => setCopied(false), COPY_FEEDBACK_DURATION_MS);
      }
    }
  };

  interface TiptapMark {
    type: string;
    attrs?: { href?: string };
  }

  interface TiptapNode {
    type?: string;
    content?: TiptapNode[];
    text?: string;
    marks?: TiptapMark[];
    attrs?: { src?: string; alt?: string };
  }

  const renderTextWithMarks = (text: string, marks: TiptapMark[] | undefined, key: number): React.ReactNode => {
    if (!marks || marks.length === 0) {
      return <span key={key}>{text}</span>;
    }

    let element: React.ReactNode = text;

    // Apply marks in order
    for (const mark of marks) {
      switch (mark.type) {
        case 'bold':
          element = <strong>{element}</strong>;
          break;
        case 'italic':
          element = <em>{element}</em>;
          break;
        case 'code':
          element = <code>{element}</code>;
          break;
        case 'strike':
          element = <s>{element}</s>;
          break;
        case 'link':
          element = <a href={mark.attrs?.href} target="_blank" rel="noopener noreferrer">{element}</a>;
          break;
      }
    }

    return <span key={key}>{element}</span>;
  };

  const renderContent = () => {
    // Try to extract text content from the Tiptap JSON
    if (note.content && typeof note.content === 'object') {
      const content = note.content as { content?: TiptapNode[] };
      const elements: React.ReactNode[] = [];
      let key = 0;

      const extractNodes = (nodes: TiptapNode[] | undefined): void => {
        if (!nodes) return;
        for (const node of nodes) {
          if (node.type === 'codeBlock') {
            // Extract text from code block content
            const codeText = node.content?.map(n => n.text || '').join('') || '';
            elements.push(
              <pre key={key++} className="code-block">
                <code>{codeText}</code>
              </pre>
            );
          } else if (node.text) {
            elements.push(renderTextWithMarks(node.text, node.marks, key++));
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
    // Don't show "(image)" placeholder if we have images
    if (note.plain_text === '(image)' && images.length > 0) {
      return null;
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
          {renderContent() && (
            <p className={note.is_done ? 'strikethrough' : ''}>{renderContent()}</p>
          )}
          {images.length > 0 && (
            <div className="note-images">
              {images.map((img) => (
                <img key={img.id} src={img.url} alt="" />
              ))}
            </div>
          )}
          {note.link_previews && note.link_previews.length > 0 && (
            <div className="note-link-previews">
              {note.link_previews.map((preview) => (
                <LinkPreviewCard key={preview.id} preview={preview} />
              ))}
            </div>
          )}
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
          <div className="note-time-row">
            <span className="note-time">
              {note.created_at && isValid(new Date(note.created_at))
                ? format(new Date(note.created_at), 'h:mm a')
                : ''}
            </span>
            <button
              className={`share-btn ${note.is_public ? 'is-public' : ''}`}
              onClick={handleTogglePublic}
              title={note.is_public ? 'Make private' : 'Make public'}
            >
              {note.is_public ? <Globe size={14} /> : <GlobeLock size={14} />}
            </button>
          </div>
          <div className="note-actions">
            {note.is_public && (
              <button
                className={`copy-link-btn ${copied ? 'copied' : ''}`}
                onClick={handleCopyLink}
                title={copied ? 'Copied!' : 'Copy link'}
              >
                <Link2 size={14} />
                {copied && <span className="copied-text">Copied!</span>}
              </button>
            )}
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

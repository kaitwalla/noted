import React, { useState, useEffect } from 'react';
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
  const { toggleNoteDone, toggleNotePublic, removeNote, updateNote } = useStore();

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
    attrs?: { src?: string; alt?: string; level?: number; checked?: boolean };
  }

  // Toggle a task item's checked state and save
  const toggleTaskItem = async (taskIndex: number) => {
    if (!note.content || typeof note.content !== 'object') return;

    // Deep clone the content
    const newContent = JSON.parse(JSON.stringify(note.content)) as { content?: TiptapNode[] };

    // Find and toggle the task item at the given index
    let currentIndex = 0;
    const findAndToggle = (nodes: TiptapNode[] | undefined): boolean => {
      if (!nodes) return false;
      for (const node of nodes) {
        if (node.type === 'taskItem') {
          if (currentIndex === taskIndex) {
            node.attrs = node.attrs || {};
            node.attrs.checked = !node.attrs.checked;
            return true;
          }
          currentIndex++;
        }
        if (node.content && findAndToggle(node.content)) {
          return true;
        }
      }
      return false;
    };

    if (findAndToggle(newContent.content)) {
      // Generate new plain text
      const extractText = (nodes: TiptapNode[] | undefined): string => {
        if (!nodes) return '';
        return nodes.map(n => {
          if (n.text) return n.text;
          if (n.content) return extractText(n.content);
          return '';
        }).join('');
      };
      const plainText = extractText(newContent.content);

      await updateNote(note.id, {
        content: newContent,
        plain_text: plainText,
      });
    }
  };

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
      const parsed = typeof note.content === 'string' ? JSON.parse(note.content) : note.content;
      const content = parsed as { content?: TiptapNode[] };
      let keyCounter = 0;
      let taskItemIndex = 0;

      const renderNode = (node: TiptapNode): React.ReactNode => {
        const key = keyCounter++;

        switch (node.type) {
          case 'heading': {
            const level = node.attrs?.level || 1;
            const children = node.content?.map(renderNode);
            return React.createElement(`h${level}`, { key, className: 'note-heading' }, children);
          }

          case 'paragraph': {
            const children = node.content?.map(renderNode);
            return <p key={key}>{children}</p>;
          }

          case 'bulletList': {
            const items = node.content?.map(renderNode);
            return <ul key={key}>{items}</ul>;
          }

          case 'orderedList': {
            const items = node.content?.map(renderNode);
            return <ol key={key}>{items}</ol>;
          }

          case 'listItem': {
            const children = node.content?.map(renderNode);
            return <li key={key}>{children}</li>;
          }

          case 'taskList': {
            const items = node.content?.map(renderNode);
            return <ul key={key} className="task-list">{items}</ul>;
          }

          case 'taskItem': {
            const checked = node.attrs?.checked || false;
            const currentTaskIndex = taskItemIndex++;
            const children = node.content?.map(renderNode);
            return (
              <li key={key} className={`task-item ${checked ? 'checked' : ''}`}>
                <button
                  className="task-checkbox"
                  onClick={() => toggleTaskItem(currentTaskIndex)}
                  type="button"
                >
                  {checked ? '☑' : '☐'}
                </button>
                {children}
              </li>
            );
          }

          case 'codeBlock': {
            const codeText = node.content?.map(n => n.text || '').join('') || '';
            return (
              <pre key={key} className="code-block">
                <code>{codeText}</code>
              </pre>
            );
          }

          case 'blockquote': {
            const children = node.content?.map(renderNode);
            return <blockquote key={key}>{children}</blockquote>;
          }

          case 'horizontalRule': {
            return <hr key={key} />;
          }

          case 'text': {
            return renderTextWithMarks(node.text || '', node.marks, key);
          }

          default: {
            // For text nodes without explicit type
            if (node.text) {
              return renderTextWithMarks(node.text, node.marks, key);
            }
            // Recursively render content for unknown node types
            if (Array.isArray(node.content)) {
              return <span key={key}>{node.content.map(renderNode)}</span>;
            }
            return null;
          }
        }
      };

      if (Array.isArray(content.content) && content.content.length > 0) {
        const elements = content.content.map(renderNode).filter(Boolean);
        if (elements.length > 0) {
          return <div className="rendered-content">{elements}</div>;
        }
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
        <div className={`note-content ${note.is_done ? 'strikethrough' : ''}`}>
          {renderContent()}
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

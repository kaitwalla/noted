import { useEffect, useState } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import TiptapImage from '@tiptap/extension-image';
import { X, Save } from 'lucide-react';
import { useStore } from '../../store';
import type { Note } from '../../types';

interface NoteEditModalProps {
  note: Note;
  onClose: () => void;
}

export function NoteEditModal({ note, onClose }: NoteEditModalProps) {
  const [isTodo, setIsTodo] = useState(note.is_todo);
  const [isSaving, setIsSaving] = useState(false);
  const { updateNote } = useStore();

  const editor = useEditor({
    extensions: [StarterKit, TiptapImage],
    content: note.content,
    editorProps: {
      attributes: {
        class: 'note-edit-editor',
      },
    },
  });

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [onClose]);

  const handleSave = async () => {
    if (!editor || isSaving) return;

    const content = editor.getJSON();
    const plainText = editor.getText().trim();

    setIsSaving(true);
    try {
      await updateNote(note.id, {
        content,
        plain_text: plainText,
        is_todo: isTodo,
      });
      onClose();
    } catch (error) {
      console.error('Failed to save note:', error);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Edit Note</h3>
          <button className="icon-btn" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        <div className="modal-body">
          <EditorContent editor={editor} />
          <label className="checkbox-label">
            <input
              type="checkbox"
              checked={isTodo}
              onChange={(e) => setIsTodo(e.target.checked)}
            />
            <span>This is a to-do item</span>
          </label>
        </div>
        <div className="modal-footer">
          <button className="btn-secondary" onClick={onClose}>
            Cancel
          </button>
          <button className="btn-primary" onClick={handleSave} disabled={isSaving}>
            <Save size={16} />
            {isSaving ? 'Saving...' : 'Save'}
          </button>
        </div>
      </div>
    </div>
  );
}

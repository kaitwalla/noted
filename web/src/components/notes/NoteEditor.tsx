import { useState, useRef, type KeyboardEvent } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import TiptapImage from '@tiptap/extension-image';
import Placeholder from '@tiptap/extension-placeholder';
import { Send, CheckSquare, Image, Clock, Tag, X } from 'lucide-react';
import { useStore } from '../../store';
import { api } from '../../api/client';
import { format } from 'date-fns';

interface PendingImage {
  file: File;
  preview: string;
}

export function NoteEditor() {
  const [isTodo, setIsTodo] = useState(false);
  const [showTagPicker, setShowTagPicker] = useState(false);
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>([]);
  const [reminderDate, setReminderDate] = useState<string>('');
  const [showReminderPicker, setShowReminderPicker] = useState(false);
  const [pendingImages, setPendingImages] = useState<PendingImage[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const { selectedNotebookId, addNote, fetchNotes, tags } = useStore();

  const editor = useEditor({
    extensions: [
      StarterKit,
      TiptapImage.configure({
        inline: true,
      }),
      Placeholder.configure({
        placeholder: 'Write a note...',
      }),
    ],
    editorProps: {
      attributes: {
        class: 'note-input-editor',
      },
    },
  });

  const handleSubmit = async () => {
    if (!editor || !selectedNotebookId || isSubmitting) return;

    const content = editor.getJSON();
    const plainText = editor.getText().trim();

    if (!plainText && pendingImages.length === 0) return;

    setIsSubmitting(true);
    try {
      // Create the note first
      const note = await addNote(
        selectedNotebookId,
        content,
        plainText || '(image)',
        isTodo,
        selectedTagIds,
        reminderDate ? new Date(reminderDate).toISOString() : undefined
      );

      // Upload any pending images (they're associated with the note by note_id)
      if (pendingImages.length > 0) {
        for (const pending of pendingImages) {
          try {
            await api.uploadImage(note.id, pending.file);
          } catch (err) {
            console.error('Failed to upload image:', err);
          }
          URL.revokeObjectURL(pending.preview);
        }
        // Refresh notes to trigger NoteBubble to re-fetch images
        await fetchNotes(selectedNotebookId);
      }

      editor.commands.clearContent();
      setIsTodo(false);
      setSelectedTagIds([]);
      setReminderDate('');
      setShowReminderPicker(false);
      setShowTagPicker(false);
      setPendingImages([]);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  const handleImageClick = () => {
    fileInputRef.current?.click();
  };

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || !editor) return;

    const newPending: PendingImage[] = [];
    for (const file of Array.from(files)) {
      const preview = URL.createObjectURL(file);
      newPending.push({ file, preview });
    }
    setPendingImages((prev) => [...prev, ...newPending]);

    // Clear the input
    e.target.value = '';
  };

  const removeImage = (index: number) => {
    setPendingImages((prev) => {
      const removed = prev[index];
      URL.revokeObjectURL(removed.preview);
      return prev.filter((_, i) => i !== index);
    });
  };

  const toggleTag = (tagId: string) => {
    setSelectedTagIds((prev) =>
      prev.includes(tagId) ? prev.filter((id) => id !== tagId) : [...prev, tagId]
    );
  };

  const selectedTags = tags.filter((t) => selectedTagIds.includes(t.id));

  return (
    <div className="note-editor">
      {(selectedTags.length > 0 || reminderDate || pendingImages.length > 0) && (
        <div className="editor-attachments">
          {selectedTags.map((tag) => (
            <span
              key={tag.id}
              className="attached-tag"
              style={{ backgroundColor: tag.color || '#6366f1' }}
            >
              {tag.name}
              <button onClick={() => toggleTag(tag.id)}>
                <X size={12} />
              </button>
            </span>
          ))}
          {reminderDate && (
            <span className="attached-reminder">
              <Clock size={12} />
              {format(new Date(reminderDate), 'MMM d, h:mm a')}
              <button onClick={() => setReminderDate('')}>
                <X size={12} />
              </button>
            </span>
          )}
        </div>
      )}

      {pendingImages.length > 0 && (
        <div className="pending-images">
          {pendingImages.map((img, idx) => (
            <div key={idx} className="pending-image">
              <img src={img.preview} alt={img.file.name} />
              <button className="remove-image" onClick={() => removeImage(idx)}>
                <X size={14} />
              </button>
            </div>
          ))}
        </div>
      )}

      <div className="editor-container" onKeyDown={handleKeyDown}>
        <EditorContent editor={editor} />
      </div>

      <div className="editor-toolbar">
        <div className="toolbar-left">
          <button
            className={`toolbar-btn ${isTodo ? 'active' : ''}`}
            onClick={() => setIsTodo(!isTodo)}
            title="Make this a to-do"
          >
            <CheckSquare size={18} />
          </button>

          <div className="toolbar-dropdown">
            <button
              className={`toolbar-btn ${selectedTagIds.length > 0 ? 'active' : ''}`}
              onClick={() => setShowTagPicker(!showTagPicker)}
              title="Add tags"
            >
              <Tag size={18} />
            </button>
            {showTagPicker && (
              <div className="dropdown-menu tag-dropdown">
                {tags.length === 0 ? (
                  <div className="dropdown-empty">No tags yet</div>
                ) : (
                  tags.map((tag) => (
                    <button
                      key={tag.id}
                      className={`dropdown-item ${selectedTagIds.includes(tag.id) ? 'selected' : ''}`}
                      onClick={() => toggleTag(tag.id)}
                    >
                      <span className="tag-dot" style={{ backgroundColor: tag.color || '#6366f1' }} />
                      {tag.name}
                    </button>
                  ))
                )}
              </div>
            )}
          </div>

          <div className="toolbar-dropdown">
            <button
              className={`toolbar-btn ${reminderDate ? 'active' : ''}`}
              onClick={() => setShowReminderPicker(!showReminderPicker)}
              title="Set reminder"
            >
              <Clock size={18} />
            </button>
            {showReminderPicker && (
              <div className="dropdown-menu reminder-dropdown">
                <input
                  type="datetime-local"
                  value={reminderDate}
                  onChange={(e) => setReminderDate(e.target.value)}
                  min={new Date().toISOString().slice(0, 16)}
                />
                {reminderDate && (
                  <button className="btn-small" onClick={() => setReminderDate('')}>
                    Clear
                  </button>
                )}
              </div>
            )}
          </div>

          <button className="toolbar-btn" onClick={handleImageClick} title="Add image">
            <Image size={18} />
          </button>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            multiple
            onChange={handleImageSelect}
            style={{ display: 'none' }}
          />
        </div>

        <button
          className={`toolbar-btn send-btn ${isSubmitting ? 'disabled' : ''}`}
          onClick={handleSubmit}
          title="Send (Enter)"
          disabled={isSubmitting}
        >
          <Send size={18} />
        </button>
      </div>
    </div>
  );
}

import { useState, useEffect } from 'react';
import { X, Plus, Trash2 } from 'lucide-react';
import { useStore } from '../../store';

interface TagsPanelProps {
  isOpen: boolean;
  onClose: () => void;
}

const TAG_COLORS = [
  '#ef4444', // red
  '#f97316', // orange
  '#eab308', // yellow
  '#22c55e', // green
  '#06b6d4', // cyan
  '#3b82f6', // blue
  '#8b5cf6', // violet
  '#ec4899', // pink
];

export function TagsPanel({ isOpen, onClose }: TagsPanelProps) {
  const [newTagName, setNewTagName] = useState('');
  const [selectedColor, setSelectedColor] = useState(TAG_COLORS[0]);
  const [isAdding, setIsAdding] = useState(false);
  const { tags, fetchTags, addTag, removeTag } = useStore();

  useEffect(() => {
    if (isOpen) {
      fetchTags();
    }
  }, [isOpen, fetchTags]);

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    if (isOpen) {
      window.addEventListener('keydown', handleEscape);
      return () => window.removeEventListener('keydown', handleEscape);
    }
  }, [isOpen, onClose]);

  const handleAddTag = async () => {
    if (!newTagName.trim()) return;
    try {
      await addTag(newTagName.trim(), selectedColor);
      setNewTagName('');
      setIsAdding(false);
    } catch (error) {
      console.error('Failed to add tag:', error);
    }
  };

  const handleDeleteTag = async (id: string, name: string) => {
    if (confirm(`Delete tag "${name}"? It will be removed from all notes.`)) {
      await removeTag(id);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="panel-overlay" onClick={onClose}>
      <div className="panel tags-panel" onClick={(e) => e.stopPropagation()}>
        <div className="panel-header">
          <h3>Manage Tags</h3>
          <button className="icon-btn" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <div className="panel-body">
          {isAdding ? (
            <div className="add-tag-form">
              <input
                type="text"
                placeholder="Tag name..."
                value={newTagName}
                onChange={(e) => setNewTagName(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleAddTag();
                  if (e.key === 'Escape') setIsAdding(false);
                }}
                autoFocus
              />
              <div className="color-picker">
                {TAG_COLORS.map((color) => (
                  <button
                    key={color}
                    className={`color-option ${selectedColor === color ? 'selected' : ''}`}
                    style={{ backgroundColor: color }}
                    onClick={() => setSelectedColor(color)}
                  />
                ))}
              </div>
              <div className="form-actions">
                <button onClick={handleAddTag} className="btn-small">Create</button>
                <button onClick={() => setIsAdding(false)} className="btn-small btn-secondary">Cancel</button>
              </div>
            </div>
          ) : (
            <button className="add-tag-btn" onClick={() => setIsAdding(true)}>
              <Plus size={16} />
              <span>Add new tag</span>
            </button>
          )}

          <div className="tags-list">
            {tags.length === 0 && !isAdding && (
              <div className="empty-tags">No tags yet. Create one to organize your notes.</div>
            )}
            {tags.map((tag) => (
              <div key={tag.id} className="tag-item">
                <span className="tag-color" style={{ backgroundColor: tag.color || '#6366f1' }} />
                <span className="tag-name">{tag.name}</span>
                <button
                  className="delete-tag-btn"
                  onClick={() => handleDeleteTag(tag.id, tag.name)}
                  title="Delete tag"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

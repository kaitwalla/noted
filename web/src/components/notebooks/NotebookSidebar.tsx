import { useEffect, useState } from 'react';
import { Book, Plus, Trash2, LogOut, Search, Tag } from 'lucide-react';
import { useStore } from '../../store';
import { SearchPanel } from '../common/SearchPanel';
import { TagsPanel } from '../common/TagsPanel';

interface NotebookSidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

export function NotebookSidebar({ isOpen, onClose }: NotebookSidebarProps) {
  const [newTitle, setNewTitle] = useState('');
  const [isAdding, setIsAdding] = useState(false);
  const [showSearch, setShowSearch] = useState(false);
  const [showTags, setShowTags] = useState(false);
  const {
    notebooks,
    selectedNotebookId,
    fetchNotebooks,
    selectNotebook,
    addNotebook,
    removeNotebook,
    logout,
    user,
  } = useStore();

  useEffect(() => {
    fetchNotebooks();
  }, [fetchNotebooks]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setShowSearch(true);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const handleAdd = async () => {
    if (!newTitle.trim()) return;
    try {
      const notebook = await addNotebook(newTitle.trim());
      setNewTitle('');
      setIsAdding(false);
      handleSelectNotebook(notebook.id);
    } catch (error) {
      console.error('Failed to add notebook:', error);
    }
  };

  const handleDelete = async (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    if (confirm('Delete this notebook and all its notes?')) {
      await removeNotebook(id);
    }
  };

  const handleSelectNotebook = (id: string) => {
    selectNotebook(id);
    onClose(); // Close sidebar on mobile after selecting
  };

  return (
    <>
      <aside className={`sidebar ${isOpen ? 'open' : ''}`}>
        <div className="sidebar-header">
          <h2>Noted</h2>
          <button className="icon-btn" onClick={() => setIsAdding(true)} title="New notebook">
            <Plus size={20} />
          </button>
        </div>

        <div className="sidebar-actions">
          <button className="action-btn" onClick={() => setShowSearch(true)}>
            <Search size={16} />
            <span>Search</span>
            <kbd>⌘K</kbd>
          </button>
          <button className="action-btn" onClick={() => setShowTags(true)}>
            <Tag size={16} />
            <span>Tags</span>
          </button>
        </div>

        {isAdding && (
          <div className="add-notebook-form">
            <input
              type="text"
              placeholder="Notebook name..."
              value={newTitle}
              onChange={(e) => setNewTitle(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') handleAdd();
                if (e.key === 'Escape') setIsAdding(false);
              }}
              autoFocus
            />
            <div className="form-actions">
              <button onClick={handleAdd} className="btn-small">Add</button>
              <button onClick={() => setIsAdding(false)} className="btn-small btn-secondary">Cancel</button>
            </div>
          </div>
        )}

        <div className="notebook-list">
          {notebooks.map((notebook) => (
            <div
              key={notebook.id}
              className={`notebook-item ${selectedNotebookId === notebook.id ? 'active' : ''}`}
              onClick={() => handleSelectNotebook(notebook.id)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault();
                  handleSelectNotebook(notebook.id);
                }
              }}
            >
              <Book size={18} />
              <span>{notebook.title}</span>
              <button
                className="delete-btn"
                onClick={(e) => handleDelete(e, notebook.id)}
                title="Delete notebook"
              >
                <Trash2 size={14} />
              </button>
            </div>
          ))}

          {notebooks.length === 0 && (
            <div className="empty-notebooks">
              <p>No notebooks yet</p>
              <button className="btn-small" onClick={() => setIsAdding(true)}>
                Create one
              </button>
            </div>
          )}
        </div>

        <div className="sidebar-footer">
          <div className="user-info">
            <span>{user?.email}</span>
          </div>
          <button className="icon-btn" onClick={logout} title="Sign out">
            <LogOut size={18} />
          </button>
        </div>
      </aside>

      <SearchPanel isOpen={showSearch} onClose={() => setShowSearch(false)} />
      <TagsPanel isOpen={showTags} onClose={() => setShowTags(false)} />
    </>
  );
}

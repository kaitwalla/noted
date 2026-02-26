import { useState, useEffect, useCallback } from 'react';
import { Search, X } from 'lucide-react';
import { api } from '../../api/client';
import { NoteBubble } from '../notes/NoteBubble';
import type { Note } from '../../types';

interface SearchPanelProps {
  isOpen: boolean;
  onClose: () => void;
}

export function SearchPanel({ isOpen, onClose }: SearchPanelProps) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Note[]>([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);

  const doSearch = useCallback(async (searchQuery: string) => {
    if (!searchQuery.trim()) {
      setResults([]);
      setSearched(false);
      return;
    }

    setLoading(true);
    try {
      const notes = await api.search(searchQuery);
      setResults(notes);
      setSearched(true);
    } catch (err) {
      console.error('Search failed:', err);
      setResults([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => {
      doSearch(query);
    }, 300);
    return () => clearTimeout(timer);
  }, [query, doSearch]);

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    if (isOpen) {
      window.addEventListener('keydown', handleEscape);
      return () => window.removeEventListener('keydown', handleEscape);
    }
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div className="search-panel-overlay" onClick={onClose}>
      <div className="search-panel" onClick={(e) => e.stopPropagation()}>
        <div className="search-header">
          <div className="search-input-wrapper">
            <Search size={20} className="search-icon" />
            <input
              type="text"
              placeholder="Search notes..."
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              autoFocus
            />
            {query && (
              <button className="clear-btn" onClick={() => setQuery('')}>
                <X size={16} />
              </button>
            )}
          </div>
          <button className="close-btn" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <div className="search-results">
          {loading && <div className="search-loading">Searching...</div>}

          {!loading && searched && results.length === 0 && (
            <div className="search-empty">No notes found for "{query}"</div>
          )}

          {!loading && results.length > 0 && (
            <div className="results-list">
              <div className="results-count">{results.length} result{results.length !== 1 ? 's' : ''}</div>
              {results.map((note) => (
                <NoteBubble key={note.id} note={note} />
              ))}
            </div>
          )}

          {!loading && !searched && (
            <div className="search-hint">Start typing to search your notes</div>
          )}
        </div>
      </div>
    </div>
  );
}

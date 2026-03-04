import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { format, isValid } from 'date-fns';
import { AlertCircle } from 'lucide-react';
import { api } from '../../api/client';
import type { Note } from '../../types';

interface TiptapNode {
  type?: string;
  content?: TiptapNode[];
  text?: string;
  attrs?: { src?: string; alt?: string };
}

function renderNoteContent(note: Note): React.ReactNode {
  if (note.content && typeof note.content === 'object') {
    const content = note.content as { content?: TiptapNode[] };
    const elements: React.ReactNode[] = [];
    let key = 0;

    const extractNodes = (nodes: TiptapNode[] | undefined): void => {
      if (!nodes) return;
      for (const node of nodes) {
        if (node.text) {
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
}

export function PublicNoteView() {
  const { noteId } = useParams<{ noteId: string }>();
  const [note, setNote] = useState<Note | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [images, setImages] = useState<Array<{ id: string; url: string }>>([]);

  useEffect(() => {
    let isMounted = true;

    if (!noteId) {
      setError('Invalid note link');
      setLoading(false);
      return;
    }

    const fetchNote = async () => {
      try {
        const publicNote = await api.getPublicNote(noteId);
        if (!isMounted) return;
        setNote(publicNote);

        // Fetch images for this public note
        try {
          const noteImages = await api.getPublicNoteImages(noteId);
          if (isMounted) {
            setImages(noteImages.map((img) => ({ id: img.id, url: img.url })));
          }
        } catch {
          // Images might not be accessible, ignore error
        }
      } catch {
        if (isMounted) {
          setError('Note not found or is private');
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    fetchNote();

    return () => {
      isMounted = false;
    };
  }, [noteId]);

  if (loading) {
    return (
      <div className="public-note-container">
        <div className="public-note-loading">Loading...</div>
      </div>
    );
  }

  if (error || !note) {
    return (
      <div className="public-note-container">
        <header className="public-note-header">
          <Link to="/" className="public-note-brand">
            <img src="/logo.png" alt="Noted" style={{ width: 24, height: 24, borderRadius: '50%' }} />
            <span>Noted</span>
          </Link>
        </header>
        <div className="public-note-error">
          <AlertCircle size={48} />
          <h2>Note Not Found</h2>
          <p>{error || 'This note does not exist or is not public.'}</p>
          <Link to="/" className="btn-primary">Go to Noted</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="public-note-container">
      <header className="public-note-header">
        <Link to="/" className="public-note-brand">
          <img src="/logo.png" alt="Noted" style={{ width: 24, height: 24, borderRadius: '50%' }} />
          <span>Noted</span>
        </Link>
      </header>
      <main className="public-note-main">
        <article className="public-note-card">
          <div className="public-note-content">
            <p>{renderNoteContent(note)}</p>
            {images.length > 0 && (
              <div className="public-note-images">
                {images.map((img) => (
                  <img key={img.id} src={img.url} alt="" />
                ))}
              </div>
            )}
          </div>
          {note.tags && note.tags.length > 0 && (
            <div className="public-note-tags">
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
          <div className="public-note-meta">
            <span className="public-note-time">
              {note.created_at && isValid(new Date(note.created_at))
                ? format(new Date(note.created_at), 'MMMM d, yyyy · h:mm a')
                : ''}
            </span>
          </div>
        </article>
      </main>
    </div>
  );
}

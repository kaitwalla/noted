import { X, Check } from 'lucide-react';
import { useStore, themeOptions, type AppTheme } from '../../store';

interface ThemePanelProps {
  isOpen: boolean;
  onClose: () => void;
}

export function ThemePanel({ isOpen, onClose }: ThemePanelProps) {
  const { theme, setTheme } = useStore();

  if (!isOpen) return null;

  const handleSelect = (themeId: AppTheme) => {
    setTheme(themeId);
  };

  return (
    <div className="panel-overlay" onClick={onClose}>
      <div className="panel" onClick={(e) => e.stopPropagation()}>
        <div className="panel-header">
          <h3>Theme</h3>
          <button className="close-btn" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        <div className="panel-body">
          <div className="theme-list">
            {themeOptions.map((option) => (
              <button
                key={option.id}
                className={`theme-item ${theme === option.id ? 'selected' : ''}`}
                onClick={() => handleSelect(option.id)}
              >
                <span className="theme-icon">{option.icon}</span>
                <div className="theme-info">
                  <span className="theme-name">{option.name}</span>
                  <span className="theme-description">{option.description}</span>
                </div>
                {theme === option.id && (
                  <Check size={18} className="theme-check" />
                )}
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

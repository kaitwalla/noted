import type { LinkPreview } from '../../types';

interface LinkPreviewCardProps {
  preview: LinkPreview;
}

export function LinkPreviewCard({ preview }: LinkPreviewCardProps) {
  const handleClick = () => {
    window.open(preview.url, '_blank', 'noopener,noreferrer');
  };

  return (
    <div className="link-preview-card" onClick={handleClick}>
      {preview.image_url && (
        <div className="link-preview-image">
          <img
            src={preview.image_url}
            alt=""
            onError={(e) => {
              (e.target as HTMLImageElement).style.display = 'none';
            }}
          />
        </div>
      )}
      <div className="link-preview-content">
        <div className="link-preview-header">
          {preview.favicon_url && (
            <img
              src={preview.favicon_url}
              alt=""
              className="link-preview-favicon"
              onError={(e) => {
                (e.target as HTMLImageElement).style.display = 'none';
              }}
            />
          )}
          {preview.site_name && (
            <span className="link-preview-site">{preview.site_name}</span>
          )}
        </div>
        {preview.title && (
          <div className="link-preview-title">{preview.title}</div>
        )}
        {preview.description && (
          <div className="link-preview-description">{preview.description}</div>
        )}
      </div>
    </div>
  );
}

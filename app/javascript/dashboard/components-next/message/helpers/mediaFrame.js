// Shared sizing for media inside message bubbles, so photos and videos look the same whether they
// come alone, with a caption or in an album.
export const MEDIA_MAX_WIDTH = 320;
export const MEDIA_MIN_WIDTH = 160;
export const MEDIA_MAX_HEIGHT = 384;
const DEFAULT_RATIO = 4 / 3;

/**
 * Inline style for a single media frame: the real proportion of the file, never wider than
 * MEDIA_MAX_WIDTH nor taller than MEDIA_MAX_HEIGHT (extra height is cropped, the gallery shows
 * the whole picture). Small files are not stretched past their own width.
 *
 * @param {{width?: number|null, height?: number|null}} attachment
 * @param {number} [fallbackRatio] ratio used when the file has no dimensions
 * @returns {Object}
 */
export const getMediaFrameStyle = (
  attachment,
  fallbackRatio = DEFAULT_RATIO
) => {
  const width = Number(attachment?.width) || 0;
  const height = Number(attachment?.height) || 0;
  const hasSize = width > 0 && height > 0;
  const frameWidth = hasSize
    ? Math.min(Math.max(width, MEDIA_MIN_WIDTH), MEDIA_MAX_WIDTH)
    : MEDIA_MAX_WIDTH;

  return {
    width: `${frameWidth}px`,
    maxWidth: '100%',
    maxHeight: `${MEDIA_MAX_HEIGHT}px`,
    aspectRatio: hasSize ? `${width} / ${height}` : `${fallbackRatio}`,
  };
};

// Album layout: up to 4 tiles, the last one shows how many more there are.
export const ALBUM_MAX_TILES = 4;

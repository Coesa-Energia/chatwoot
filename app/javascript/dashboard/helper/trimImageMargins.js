// Logos usually come with a lot of empty margin (a wide banner with the artwork in the middle), which makes
// them look tiny in the sidebar. This crops transparent and white margins before the image is uploaded.

const WHITE_THRESHOLD = 245;
const ALPHA_THRESHOLD = 12;
const PADDING_RATIO = 0.04;
const MAX_ANALYSIS_SIDE = 2400;
// Nothing to gain when the artwork already fills almost the whole image.
const ALREADY_TIGHT_RATIO = 0.96;

/**
 * Bounding box of the pixels that are neither transparent nor (almost) white, or null for a blank image.
 * `data` is RGBA, like ImageData.data.
 */
export const findContentBounds = ({ data, width, height }) => {
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const i = (y * width + x) * 4;
      const isBackground =
        data[i + 3] <= ALPHA_THRESHOLD ||
        (data[i] >= WHITE_THRESHOLD &&
          data[i + 1] >= WHITE_THRESHOLD &&
          data[i + 2] >= WHITE_THRESHOLD);
      if (!isBackground) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX < 0) return null;
  return { x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1 };
};

// Adds a little air around the artwork without leaving the image.
export const padBounds = (bounds, imageWidth, imageHeight) => {
  const pad = Math.round(Math.max(bounds.width, bounds.height) * PADDING_RATIO);
  const x = Math.max(0, bounds.x - pad);
  const y = Math.max(0, bounds.y - pad);
  return {
    x,
    y,
    width: Math.min(imageWidth, bounds.x + bounds.width + pad) - x,
    height: Math.min(imageHeight, bounds.y + bounds.height + pad) - y,
  };
};

export const isAlreadyTight = (bounds, imageWidth, imageHeight) =>
  bounds.width >= imageWidth * ALREADY_TIGHT_RATIO &&
  bounds.height >= imageHeight * ALREADY_TIGHT_RATIO;

/**
 * Returns a new PNG File without the empty margins, or the original file when it cannot or need not be
 * trimmed (animated GIFs, blank images, artwork that already fills the image, or any error).
 */
export const trimImageMargins = async file => {
  if (!file || file.type === 'image/gif') return file;

  try {
    const bitmap = await createImageBitmap(file);
    const scale = Math.min(
      1,
      MAX_ANALYSIS_SIDE / Math.max(bitmap.width, bitmap.height)
    );
    const width = Math.round(bitmap.width * scale);
    const height = Math.round(bitmap.height * scale);

    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext('2d', { willReadFrequently: true });
    context.drawImage(bitmap, 0, 0, width, height);

    const content = findContentBounds(
      context.getImageData(0, 0, width, height)
    );
    if (!content || isAlreadyTight(content, width, height)) return file;

    const crop = padBounds(content, width, height);
    const output = document.createElement('canvas');
    output.width = crop.width;
    output.height = crop.height;
    output
      .getContext('2d')
      .drawImage(
        canvas,
        crop.x,
        crop.y,
        crop.width,
        crop.height,
        0,
        0,
        crop.width,
        crop.height
      );

    const blob = await new Promise(resolve => {
      output.toBlob(resolve, 'image/png');
    });
    if (!blob) return file;
    return new File([blob], file.name.replace(/\.[^.]+$/, '') + '.png', {
      type: 'image/png',
    });
  } catch {
    return file;
  }
};

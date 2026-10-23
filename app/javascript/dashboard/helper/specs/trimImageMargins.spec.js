import {
  findContentBounds,
  padBounds,
  isAlreadyTight,
  trimImageMargins,
} from '../trimImageMargins';

// Builds RGBA pixel data: every pixel `fill`, with a rectangle of `paint` pixels.
const image = ({ width, height, fill, paint, rect }) => {
  const data = new Uint8ClampedArray(width * height * 4);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const inside =
        x >= rect.x &&
        x < rect.x + rect.width &&
        y >= rect.y &&
        y < rect.y + rect.height;
      data.set(inside ? paint : fill, (y * width + x) * 4);
    }
  }
  return { data, width, height };
};

const WHITE = [255, 255, 255, 255];
const TRANSPARENT = [0, 0, 0, 0];
const GREEN = [30, 100, 40, 255];

describe('findContentBounds', () => {
  it('finds the artwork inside white margins', () => {
    const pixels = image({
      width: 20,
      height: 10,
      fill: WHITE,
      paint: GREEN,
      rect: { x: 5, y: 2, width: 8, height: 4 },
    });

    expect(findContentBounds(pixels)).toEqual({
      x: 5,
      y: 2,
      width: 8,
      height: 4,
    });
  });

  it('ignores transparent margins too', () => {
    const pixels = image({
      width: 10,
      height: 10,
      fill: TRANSPARENT,
      paint: GREEN,
      rect: { x: 1, y: 1, width: 3, height: 3 },
    });

    expect(findContentBounds(pixels)).toEqual({
      x: 1,
      y: 1,
      width: 3,
      height: 3,
    });
  });

  it('returns null for a blank image', () => {
    const pixels = image({
      width: 4,
      height: 4,
      fill: WHITE,
      paint: WHITE,
      rect: { x: 0, y: 0, width: 0, height: 0 },
    });

    expect(findContentBounds(pixels)).toBeNull();
  });
});

describe('padBounds', () => {
  it('adds a little air but never leaves the image', () => {
    const padded = padBounds({ x: 2, y: 1, width: 100, height: 40 }, 110, 50);

    expect(padded.x).toBe(0);
    expect(padded.y).toBe(0);
    expect(padded.x + padded.width).toBeLessThanOrEqual(110);
    expect(padded.y + padded.height).toBeLessThanOrEqual(50);
    expect(padded.width).toBeGreaterThanOrEqual(100);
  });
});

describe('isAlreadyTight', () => {
  it('is true when the artwork fills the image', () => {
    expect(isAlreadyTight({ width: 99, height: 49 }, 100, 50)).toBe(true);
  });

  it('is false when there is a lot of margin', () => {
    expect(isAlreadyTight({ width: 40, height: 20 }, 100, 50)).toBe(false);
  });
});

describe('trimImageMargins', () => {
  it('leaves animated GIFs and missing files alone', async () => {
    const gif = new File(['x'], 'logo.gif', { type: 'image/gif' });

    expect(await trimImageMargins(gif)).toBe(gif);
    expect(await trimImageMargins(null)).toBeNull();
  });

  it('returns the original file when the image cannot be read', async () => {
    const broken = new File(['not an image'], 'logo.png', {
      type: 'image/png',
    });

    expect(await trimImageMargins(broken)).toBe(broken);
  });
});

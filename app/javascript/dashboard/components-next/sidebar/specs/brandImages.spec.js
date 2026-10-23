import { resolveBrandImage } from '../brandImages';

const account = { logo_url: '/main.png', collapsed_logo_url: '/icon.png' };

describe('resolveBrandImage', () => {
  it('uses the main logo by default', () => {
    expect(resolveBrandImage(account)).toBe('/main.png');
    expect(resolveBrandImage(account, 'text')).toBe('/main.png');
  });

  it('uses the collapsed image for the collapsed sidebar', () => {
    expect(resolveBrandImage(account, 'collapsed')).toBe('/icon.png');
  });

  it('falls back to the main logo when no collapsed image was uploaded', () => {
    expect(resolveBrandImage({ logo_url: '/main.png' }, 'collapsed')).toBe(
      '/main.png'
    );
  });

  it('lets the account choose the image that goes next to the name', () => {
    const chosen = { ...account, brand_text_image: 'collapsed_logo' };

    expect(resolveBrandImage(chosen, 'text')).toBe('/icon.png');
    expect(resolveBrandImage(chosen, 'main')).toBe('/main.png');
  });

  it('returns an empty string when the account has no images', () => {
    expect(resolveBrandImage({}, 'text')).toBe('');
    expect(resolveBrandImage(undefined, 'collapsed')).toBe('');
  });
});

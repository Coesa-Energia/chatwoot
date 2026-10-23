import accountAPI from '../account';
import ApiClient from '../ApiClient';

describe('#accountAPI', () => {
  it('creates correct instance', () => {
    expect(accountAPI).toBeInstanceOf(ApiClient);
    expect(accountAPI).toHaveProperty('get');
    expect(accountAPI).toHaveProperty('show');
    expect(accountAPI).toHaveProperty('create');
    expect(accountAPI).toHaveProperty('update');
    expect(accountAPI).toHaveProperty('delete');
    expect(accountAPI).toHaveProperty('createAccount');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('#uploadLogo sends the file as multipart form data', () => {
      const file = new File(['x'], 'logo.png', { type: 'image/png' });
      accountAPI.uploadLogo(file);

      const [url, body] = axiosMock.patch.mock.calls.at(-1);
      expect(url).toMatch(/^\/api\/v1(\/accounts\/\d+)?$/);
      expect(body).toBeInstanceOf(FormData);
      expect(body.get('logo')).toBe(file);
    });

    it('#uploadLogo can send the collapsed sidebar image', () => {
      const file = new File(['x'], 'icon.png', { type: 'image/png' });
      accountAPI.uploadLogo(file, 'collapsed_logo');

      const [, body] = axiosMock.patch.mock.calls.at(-1);
      expect(body.get('collapsed_logo')).toBe(file);
      expect(body.get('logo')).toBeNull();
    });

    it('#removeLogo can remove the collapsed sidebar image', () => {
      accountAPI.removeLogo('collapsed_logo');

      expect(axiosMock.patch.mock.calls.at(-1)[1]).toEqual({
        remove_collapsed_logo: true,
      });
    });

    it('#removeLogo asks the API to remove the logo', () => {
      accountAPI.removeLogo();

      const [url, body] = axiosMock.patch.mock.calls.at(-1);
      expect(url).toMatch(/^\/api\/v1(\/accounts\/\d+)?$/);
      expect(body).toEqual({ remove_logo: true });
    });

    it('#createAccount', () => {
      accountAPI.createAccount({
        name: 'Chatwoot',
      });
      expect(axiosMock.post).toHaveBeenCalledWith('/api/v1/accounts', {
        name: 'Chatwoot',
      });
    });
  });
});

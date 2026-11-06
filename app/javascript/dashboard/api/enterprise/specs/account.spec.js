import accountAPI from '../account';
import ApiClient from '../../ApiClient';

describe('#enterpriseAccountAPI', () => {
  it('creates correct instance', () => {
    expect(accountAPI).toBeInstanceOf(ApiClient);
    expect(accountAPI).toHaveProperty('get');
    expect(accountAPI).toHaveProperty('show');
    expect(accountAPI).toHaveProperty('create');
    expect(accountAPI).toHaveProperty('update');
    expect(accountAPI).toHaveProperty('delete');
    expect(accountAPI).toHaveProperty('toggleDeletion');
    expect(accountAPI).toHaveProperty('getLimits');
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

    it('#toggleDeletion with delete action', () => {
      accountAPI.toggleDeletion('delete');
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/enterprise/api/v1/toggle_deletion',
        { action_type: 'delete' }
      );
    });

    it('#toggleDeletion with undelete action', () => {
      accountAPI.toggleDeletion('undelete');
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/enterprise/api/v1/toggle_deletion',
        { action_type: 'undelete' }
      );
    });

    it('#getLimits', () => {
      accountAPI.getLimits();
      expect(axiosMock.get).toHaveBeenCalledWith('/enterprise/api/v1/limits');
    });
  });
});

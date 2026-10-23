import inboxMembers from '../inboxMembers';

describe('#inboxMembersAPI update', () => {
  const originalAxios = window.axios;
  const axiosMock = { patch: vi.fn(() => Promise.resolve()) };

  beforeEach(() => {
    window.axios = axiosMock;
  });

  afterEach(() => {
    window.axios = originalAxios;
  });

  it('sends who may see every conversation when given', () => {
    inboxMembers.update({ inboxId: 3, agentList: [1, 2], seeAllIds: [2] });

    expect(axiosMock.patch.mock.calls.at(-1)[1]).toEqual({
      inbox_id: 3,
      user_ids: [1, 2],
      see_all_user_ids: [2],
    });
  });

  it('leaves the access untouched when not given', () => {
    inboxMembers.update({ inboxId: 3, agentList: [1, 2] });

    expect(axiosMock.patch.mock.calls.at(-1)[1]).toEqual({
      inbox_id: 3,
      user_ids: [1, 2],
    });
  });
});

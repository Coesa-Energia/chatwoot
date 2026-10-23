import conversationAPI from '../../inbox/conversation';
import ApiClient from '../../ApiClient';

describe('#ConversationAPI', () => {
  it('creates correct instance', () => {
    expect(conversationAPI).toBeInstanceOf(ApiClient);
    expect(conversationAPI).toHaveProperty('get');
    expect(conversationAPI).toHaveProperty('show');
    expect(conversationAPI).toHaveProperty('create');
    expect(conversationAPI).toHaveProperty('update');
    expect(conversationAPI).toHaveProperty('delete');
    expect(conversationAPI).toHaveProperty('toggleStatus');
    expect(conversationAPI).toHaveProperty('assignAgent');
    expect(conversationAPI).toHaveProperty('assignTeam');
    expect(conversationAPI).toHaveProperty('markMessageRead');
    expect(conversationAPI).toHaveProperty('toggleTyping');
    expect(conversationAPI).toHaveProperty('mute');
    expect(conversationAPI).toHaveProperty('unmute');
    expect(conversationAPI).toHaveProperty('meta');
    expect(conversationAPI).toHaveProperty('sendEmailTranscript');
    expect(conversationAPI).toHaveProperty('filter');
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

    it('#get conversations', () => {
      conversationAPI.get({
        inboxId: 1,
        status: 'open',
        assigneeType: 'me',
        page: 1,
        labels: [],
        teamId: 1,
        updatedWithin: 20,
      });
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/conversations', {
        params: {
          inbox_id: 1,
          team_id: 1,
          status: 'open',
          assignee_type: 'me',
          page: 1,
          labels: [],
          updated_within: 20,
        },
      });
    });

    it('#search', () => {
      conversationAPI.search({
        q: 'leads',
        page: 1,
      });

      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/conversations/search',
        {
          params: {
            q: 'leads',
            page: 1,
          },
        }
      );
    });

    it('#toggleStatus', () => {
      conversationAPI.toggleStatus({ conversationId: 12, status: 'online' });
      expect(axiosMock.post).toHaveBeenCalledWith(
        `/api/v1/conversations/12/toggle_status`,
        {
          status: 'online',
          snoozed_until: null,
        }
      );
    });

    it('#assignAgent', () => {
      conversationAPI.assignAgent({
        conversationId: 12,
        agentId: 34,
        assigneeType: 'AgentBot',
      });
      expect(axiosMock.post).toHaveBeenCalledWith(
        `/api/v1/conversations/12/assignments`,
        {
          assignee_id: 34,
          assignee_type: 'AgentBot',
        }
      );
    });

    it('#assignTeam', () => {
      conversationAPI.assignTeam({ conversationId: 12, teamId: 1 });
      expect(axiosMock.post).toHaveBeenCalledWith(
        `/api/v1/conversations/12/assignments`,
        {
          team_id: 1,
        }
      );
    });

    it('#markMessageRead', () => {
      conversationAPI.markMessageRead({ id: 12 });
      expect(axiosMock.post).toHaveBeenCalledWith(
        `/api/v1/conversations/12/update_last_seen`
      );
    });

    it('#toggleTyping', () => {
      conversationAPI.toggleTyping({
        conversationId: 12,
        status: 'typing_on',
      });
      expect(axiosMock.post).toHaveBeenCalledWith(
        `/api/v1/conversations/12/toggle_typing_status`,
        {
          typing_status: 'typing_on',
        }
      );
    });

    it('#mute', () => {
      conversationAPI.mute(45);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/conversations/45/mute'
      );
    });

    it('#unmute', () => {
      conversationAPI.unmute(45);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/conversations/45/unmute'
      );
    });

    it('#meta', () => {
      conversationAPI.meta({
        inboxId: 1,
        status: 'open',
        assigneeType: 'me',
        labels: [],
        teamId: 1,
      });
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/conversations/meta', {
        params: {
          inbox_id: 1,
          team_id: 1,
          status: 'open',
          assignee_type: 'me',
          labels: [],
        },
      });
    });

    it('#get conversations sends the unread filter only when it is on', () => {
      conversationAPI.get({ status: 'open', assigneeType: 'all', page: 1 });
      expect(axiosMock.get.mock.calls.at(-1)[1].params.unread).toBeUndefined();

      conversationAPI.get({
        status: 'open',
        assigneeType: 'all',
        page: 1,
        unread: true,
      });
      expect(axiosMock.get.mock.calls.at(-1)[1].params.unread).toBe(true);
    });

    it('#meta sends the unread filter only when it is on', () => {
      conversationAPI.meta({ status: 'open', assigneeType: 'all' });
      expect(axiosMock.get.mock.calls.at(-1)[1].params.unread).toBeUndefined();

      conversationAPI.meta({
        status: 'open',
        assigneeType: 'all',
        unread: true,
      });
      expect(axiosMock.get.mock.calls.at(-1)[1].params.unread).toBe(true);
    });

    it('#get and #meta send the awaiting reply filter only when it is on', () => {
      conversationAPI.get({ status: 'open', assigneeType: 'all', page: 1 });
      expect(
        axiosMock.get.mock.calls.at(-1)[1].params.awaiting_reply
      ).toBeUndefined();
      conversationAPI.get({
        status: 'open',
        assigneeType: 'all',
        page: 1,
        awaitingReply: true,
      });
      expect(axiosMock.get.mock.calls.at(-1)[1].params.awaiting_reply).toBe(
        true
      );

      conversationAPI.meta({ status: 'open', assigneeType: 'all' });
      expect(
        axiosMock.get.mock.calls.at(-1)[1].params.awaiting_reply
      ).toBeUndefined();
      conversationAPI.meta({
        status: 'open',
        assigneeType: 'all',
        awaitingReply: true,
      });
      expect(axiosMock.get.mock.calls.at(-1)[1].params.awaiting_reply).toBe(
        true
      );
    });

    it('#get and #meta send the archived filter only when it is on', () => {
      conversationAPI.get({ status: 'open', assigneeType: 'all', page: 1 });
      expect(
        axiosMock.get.mock.calls.at(-1)[1].params.archived
      ).toBeUndefined();
      conversationAPI.get({
        status: 'open',
        assigneeType: 'all',
        page: 1,
        archived: true,
      });
      expect(axiosMock.get.mock.calls.at(-1)[1].params.archived).toBe(true);

      conversationAPI.meta({ status: 'open', assigneeType: 'all' });
      expect(
        axiosMock.get.mock.calls.at(-1)[1].params.archived
      ).toBeUndefined();
      conversationAPI.meta({
        status: 'open',
        assigneeType: 'all',
        archived: true,
      });
      expect(axiosMock.get.mock.calls.at(-1)[1].params.archived).toBe(true);
    });

    it('#updateUserState sends only the keys that change', () => {
      conversationAPI.updateUserState({ conversationId: 12, pinned: true });
      expect(axiosMock.patch).toHaveBeenLastCalledWith(
        '/api/v1/conversations/12/user_state',
        { pinned: true }
      );

      conversationAPI.updateUserState({ conversationId: 12, archived: false });
      expect(axiosMock.patch).toHaveBeenLastCalledWith(
        '/api/v1/conversations/12/user_state',
        { archived: false }
      );

      conversationAPI.updateUserState({
        conversationId: 12,
        pinned: false,
        archived: true,
      });
      expect(axiosMock.patch).toHaveBeenLastCalledWith(
        '/api/v1/conversations/12/user_state',
        { pinned: false, archived: true }
      );
    });

    it('#sendEmailTranscript', () => {
      conversationAPI.sendEmailTranscript({
        conversationId: 45,
        email: 'john@acme.inc',
      });
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/conversations/45/transcript',
        {
          email: 'john@acme.inc',
        }
      );
    });

    it('#updateCustomAttributes', () => {
      conversationAPI.updateCustomAttributes({
        conversationId: 45,
        customAttributes: { order_d: '1001' },
      });
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/conversations/45/custom_attributes',
        {
          custom_attributes: { order_d: '1001' },
        }
      );
    });

    it('#filter', () => {
      const payload = {
        page: 1,
        sortBy: 'last_activity_at_asc',
        queryData: {
          payload: [
            {
              attribute_key: 'status',
              filter_operator: 'equal_to',
              values: ['pending', 'resolved'],
              query_operator: 'and',
            },
            {
              attribute_key: 'assignee',
              filter_operator: 'equal_to',
              values: [3],
              query_operator: 'and',
            },
            {
              attribute_key: 'id',
              filter_operator: 'equal_to',
              values: ['This is a test'],
              query_operator: null,
            },
          ],
        },
      };
      conversationAPI.filter(payload);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/conversations/filter',
        payload.queryData,
        {
          params: {
            page: payload.page,
            sort_by: payload.sortBy,
          },
        }
      );
    });

    it('#getAllAttachments', () => {
      conversationAPI.getAllAttachments(1);
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/conversations/1/attachments'
      );
    });
  });
});

import { shallowMount } from '@vue/test-utils';
import ConversationCard from '../ConversationCard.vue';

vi.mock('dashboard/composables/useSellerMode', async () => {
  const { ref } = await import('vue');
  return { useSellerMode: () => ({ isSellerMode: ref(false) }) };
});

const defaultChat = {
  id: 1,
  labels: [],
  messages: [],
  priority: null,
  unread_count: 0,
  timestamp: 1700000000,
  created_at: 1700000000,
};

const mountComponent = (chat, currentContact = {}, props = {}) =>
  shallowMount(ConversationCard, {
    props: {
      chat: { ...defaultChat, ...chat },
      currentContact: {
        name: 'Jane Doe',
        thumbnail: '',
        availability_status: 'offline',
        ...currentContact,
      },
      inbox: { id: 1 },
      ...props,
    },
    global: {
      stubs: {
        'fluent-icon': true,
      },
    },
  });

describe('ConversationCard', () => {
  it('does not reserve the labels row when only a persisted SLA policy id is present', () => {
    const wrapper = mountComponent({ sla_policy_id: 1, applied_sla: null });

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(false);
  });

  it('shows the labels row when an active applied SLA is present', () => {
    const wrapper = mountComponent({
      sla_policy_id: 1,
      applied_sla: { id: 1 },
    });

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(true);
  });

  it('does not reserve the labels row when the contact is blocked', () => {
    const wrapper = mountComponent(
      {
        sla_policy_id: 1,
        applied_sla: { id: 1 },
      },
      { blocked: true }
    );

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(false);
  });

  describe('last activity time', () => {
    const at = iso => Math.floor(new Date(iso).getTime() / 1000);
    const timestampText = chat =>
      mountComponent(chat).find('[data-testid="card-timestamp"]').text();

    beforeEach(() => {
      vi.useFakeTimers({ now: new Date('2026-10-21T15:00:00Z') });
    });
    afterEach(() => vi.useRealTimers());

    it('shows the time for today, "yesterday", and a short date for older ones', () => {
      expect(
        timestampText({ timestamp: at('2026-10-21T12:34:00Z') })
      ).toContain('12:34');
      expect(timestampText({ timestamp: at('2026-10-20T10:00:00Z') })).toBe(
        'CHAT_LIST.CHAT_TIME_STAMP.YESTERDAY'
      );
      expect(timestampText({ timestamp: at('2026-09-01T10:00:00Z') })).toBe(
        '09/01/26'
      );
    });
  });

  it('uses the bot icon for a Captain assignee', () => {
    const wrapper = mountComponent(
      { meta: { assignee_type: 'Captain::Assistant' } },
      {},
      { showAssignee: true, assignee: { name: 'Captain' } }
    );

    expect(wrapper.findComponent({ name: 'Icon' }).props('icon')).toBe(
      'i-lucide-bot'
    );
  });
});

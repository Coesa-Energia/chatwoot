import { mount } from '@vue/test-utils';
import InboxAgentAccess from '../InboxAgentAccess.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const agents = [
  { id: 1, name: 'Ana' },
  { id: 2, name: 'Bruno' },
];

const mountComponent = (modelValue = []) =>
  mount(InboxAgentAccess, {
    props: { agents, modelValue },
    global: {
      stubs: {
        Avatar: true,
        Switch: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<button class="switch" :data-on="modelValue" @click="$emit(\'update:modelValue\', !modelValue)" />',
        },
      },
    },
  });

describe('InboxAgentAccess', () => {
  it('renders nothing when the inbox has no agents', () => {
    const wrapper = mount(InboxAgentAccess, { props: { agents: [] } });

    expect(wrapper.find('[data-testid="inbox-agent-access"]').exists()).toBe(
      false
    );
  });

  it('shows one row per agent, restricted by default', () => {
    const wrapper = mountComponent();

    expect(wrapper.findAll('li')).toHaveLength(2);
    expect(
      wrapper.findAll('.switch').map(s => s.attributes('data-on'))
    ).toEqual(['false', 'false']);
    expect(wrapper.text()).toContain('INBOX_MGMT.CONVERSATION_ACCESS.OWN_ONLY');
  });

  it('adds an agent to the released list when switched on', async () => {
    const wrapper = mountComponent([2]);

    await wrapper
      .find('[data-testid="agent-access-1"] .switch')
      .trigger('click');

    expect(wrapper.emitted('update:modelValue')[0][0]).toEqual([2, 1]);
  });

  it('removes an agent from the released list when switched off', async () => {
    const wrapper = mountComponent([1, 2]);

    await wrapper
      .find('[data-testid="agent-access-1"] .switch')
      .trigger('click');

    expect(wrapper.emitted('update:modelValue')[0][0]).toEqual([2]);
  });
});

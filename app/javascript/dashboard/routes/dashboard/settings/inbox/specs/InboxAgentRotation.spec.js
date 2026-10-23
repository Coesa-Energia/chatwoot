import { mount } from '@vue/test-utils';
import InboxAgentRotation from '../InboxAgentRotation.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const agents = [
  { id: 1, name: 'Vendedor' },
  { id: 2, name: 'Suporte' },
];

const mountComponent = (modelValue = [1, 2]) =>
  mount(InboxAgentRotation, {
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

describe('InboxAgentRotation', () => {
  it('renders nothing when the inbox has no agents', () => {
    const wrapper = mount(InboxAgentRotation, { props: { agents: [] } });

    expect(wrapper.find('[data-testid="inbox-agent-rotation"]').exists()).toBe(
      false
    );
  });

  it('shows one row per agent with the switch reflecting the rotation', () => {
    const wrapper = mountComponent([1]);

    expect(wrapper.findAll('li')).toHaveLength(2);
    expect(
      wrapper.findAll('.switch').map(s => s.attributes('data-on'))
    ).toEqual(['true', 'false']);
  });

  it('takes an agent out of the rotation', async () => {
    const wrapper = mountComponent([1, 2]);

    await wrapper.findAll('.switch')[1].trigger('click');

    expect(wrapper.emitted('update:modelValue').at(-1)[0]).toEqual([1]);
  });

  it('puts an agent back in the rotation', async () => {
    const wrapper = mountComponent([1]);

    await wrapper.findAll('.switch')[1].trigger('click');

    expect(wrapper.emitted('update:modelValue').at(-1)[0]).toEqual([1, 2]);
  });
});

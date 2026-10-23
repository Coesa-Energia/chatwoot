import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import Base from '../Base.vue';

const context = {};

vi.mock('../../provider.js', () => ({
  useMessageContext: () => context,
}));

const mountNote = ({ sender = null, variant = 'private', status = 'sent' }) => {
  Object.assign(context, {
    variant: ref(variant),
    orientation: ref('right'),
    inReplyTo: ref(null),
    shouldGroupWithNext: ref(false),
    id: ref(1),
    isCaptainMessage: ref(false),
    showingOriginal: ref(false),
    sender: ref(sender),
    senderType: ref(sender?.type ?? null),
    status: ref(status),
    additionalAttributes: ref({}),
  });
  return mount(Base, {
    global: {
      stubs: {
        MessageMeta: true,
        CaptainGenerationDetails: true,
        TranslationToggle: true,
      },
    },
  });
};

const badge = '[data-testid="private-note-automation-badge"]';

describe('Base bubble private note', () => {
  it('marks a note written by an agent, without the automation badge', () => {
    const wrapper = mountNote({ sender: { name: 'Ana', type: 'User' } });
    expect(wrapper.find('[data-testid="private-note-header"]').exists()).toBe(
      true
    );
    expect(wrapper.find(badge).exists()).toBe(false);
  });

  it('flags notes from bots, Captain or the system as automation', () => {
    expect(
      mountNote({ sender: { name: 'Robô', type: 'agent_bot' } })
        .find(badge)
        .exists()
    ).toBe(true);
    expect(
      mountNote({ sender: { name: 'Captain', type: 'captain_assistant' } })
        .find(badge)
        .exists()
    ).toBe(true);
    expect(mountNote({}).find(badge).exists()).toBe(true);
    expect(mountNote({ status: 'progress' }).find(badge).exists()).toBe(false);
  });

  it('shows no note header on a normal message', () => {
    const wrapper = mountNote({ variant: 'agent' });
    expect(wrapper.find('[data-testid="private-note-header"]').exists()).toBe(
      false
    );
  });
});

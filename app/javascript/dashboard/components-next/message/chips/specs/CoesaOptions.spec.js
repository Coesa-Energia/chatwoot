import { defineComponent, ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import CoesaOptions from '../CoesaOptions.vue';
import { provideMessageContext } from '../../provider.js';

const storeState = vi.hoisted(() => ({
  getters: {},
  dispatch: vi.fn(),
}));

vi.mock('dashboard/composables/store', async () => {
  const { computed } = await import('vue');
  return {
    useMapGetter: key => computed(() => storeState.getters[key]),
    useStore: () => ({ dispatch: storeState.dispatch }),
  };
});

const BOT_NOTE_ID = 42;
const OPTIONS = [
  { titulo: 'Sim, criar', resposta: 'sim' },
  { titulo: 'Cancelar', resposta: 'não' },
  { titulo: 'Status', resposta: '/status' },
];

const mountOptions = ({
  isPrivate = true,
  sender = { id: 7, name: 'Agente Comercial', type: 'agent_bot' },
  coesaOpcoes = OPTIONS,
  messages = [],
} = {}) => {
  storeState.getters = {
    getSelectedChat: { id: 9, messages },
    getCurrentUser: { name: 'Ana', avatar_url: 'https://x/ana.png' },
    getSelectedChatAttachments: [],
  };
  const Host = defineComponent({
    components: { CoesaOptions },
    setup() {
      provideMessageContext({
        id: ref(BOT_NOTE_ID),
        conversationId: ref(9),
        contentAttributes: ref({ coesaOpcoes }),
        isPrivate: ref(isPrivate),
        sender: ref(sender),
        senderType: ref(sender?.type ?? null),
      });
    },
    template: '<CoesaOptions />',
  });
  return mount(Host);
};

const buttons = wrapper => wrapper.findAll('[data-testid="coesa-option"]');

describe('CoesaOptions', () => {
  beforeEach(() => {
    storeState.dispatch = vi.fn().mockResolvedValue(undefined);
  });

  it('shows one button per option on a private AgentBot note', () => {
    const wrapper = mountOptions();

    expect(buttons(wrapper).map(button => button.text())).toEqual([
      'Sim, criar',
      'Cancelar',
      'Status',
    ]);
    expect(buttons(wrapper).every(button => !button.element.disabled)).toBe(
      true
    );
  });

  it('shows nothing on a public message, a note from a person or without options', () => {
    expect(mountOptions({ isPrivate: false }).html()).not.toContain(
      'coesa-options'
    );
    expect(
      mountOptions({ sender: { id: 1, name: 'Ana', type: 'user' } }).html()
    ).not.toContain('coesa-options');
    expect(mountOptions({ sender: null }).html()).not.toContain(
      'coesa-options'
    );
    expect(mountOptions({ coesaOpcoes: null }).html()).not.toContain(
      'coesa-options'
    );
    expect(
      mountOptions({ coesaOpcoes: [{ titulo: 'Sem resposta' }] }).html()
    ).not.toContain('coesa-options');
  });

  it('accepts the AgentBot sender type written as a class name', () => {
    const wrapper = mountOptions({
      sender: { id: 7, name: 'Agente Comercial', type: 'AgentBot' },
    });
    expect(buttons(wrapper)).toHaveLength(3);
  });

  it('sends the answer as a private note replying to the bot note', async () => {
    const wrapper = mountOptions();

    await buttons(wrapper)[0].trigger('click');
    await flushPromises();

    expect(storeState.dispatch).toHaveBeenCalledTimes(1);
    expect(storeState.dispatch).toHaveBeenCalledWith(
      'createPendingMessageAndSend',
      {
        conversationId: 9,
        message: 'sim',
        private: true,
        sender: { name: 'Ana', thumbnail: 'https://x/ana.png' },
        contentAttributes: { in_reply_to: BOT_NOTE_ID },
      }
    );
  });

  it('locks the buttons while sending so a double click sends once', async () => {
    let resolveSend;
    storeState.dispatch = vi.fn(
      () =>
        new Promise(resolve => {
          resolveSend = resolve;
        })
    );
    const wrapper = mountOptions();

    await buttons(wrapper)[2].trigger('click');
    await buttons(wrapper)[2].trigger('click');
    await buttons(wrapper)[0].trigger('click');

    expect(storeState.dispatch).toHaveBeenCalledTimes(1);
    expect(buttons(wrapper).every(button => button.element.disabled)).toBe(
      true
    );
    expect(buttons(wrapper)[2].attributes('aria-pressed')).toBe('true');
    resolveSend();
    await flushPromises();
  });

  it('marks the chosen option once the conversation has the reply', () => {
    const wrapper = mountOptions({
      messages: [
        { id: 42, private: true, content: 'Criar o card?' },
        {
          id: 43,
          private: true,
          content: 'não',
          status: 'sent',
          content_attributes: { in_reply_to: BOT_NOTE_ID },
        },
      ],
    });

    expect(buttons(wrapper).every(button => button.element.disabled)).toBe(
      true
    );
    expect(buttons(wrapper)[1].attributes('aria-pressed')).toBe('true');
    expect(buttons(wrapper)[0].attributes('aria-pressed')).toBe('false');
  });

  it('counts a reply still being sent, and frees the buttons if it failed', () => {
    const pending = {
      id: 'tmp',
      private: true,
      content: 'sim',
      status: 'progress',
      contentAttributes: { in_reply_to: BOT_NOTE_ID },
    };
    expect(
      buttons(mountOptions({ messages: [pending] }))[0].attributes(
        'aria-pressed'
      )
    ).toBe('true');

    const failed = { ...pending, status: 'failed' };
    expect(
      buttons(mountOptions({ messages: [failed] })).every(
        button => !button.element.disabled
      )
    ).toBe(true);
  });
});

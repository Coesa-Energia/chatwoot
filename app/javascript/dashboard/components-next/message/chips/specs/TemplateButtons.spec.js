import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import TemplateButtons from '../TemplateButtons.vue';

const additionalAttributes = ref({});
const templates = [
  {
    name: 'retomar_contato',
    language: 'pt_BR',
    components: [
      { type: 'BODY', text: 'Oi {{1}}' },
      {
        type: 'BUTTONS',
        buttons: [
          { type: 'QUICK_REPLY', text: 'Quero continuar' },
          { type: 'PHONE_NUMBER', text: 'Ligar' },
        ],
      },
    ],
  },
];

vi.mock('../../provider.js', () => ({
  useMessageContext: () => ({ additionalAttributes, inboxId: ref(7) }),
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref(inboxId => (inboxId === 7 ? templates : [])),
}));

describe('TemplateButtons', () => {
  it('shows the buttons of the template the message was sent with', () => {
    additionalAttributes.value = {
      templateParams: { name: 'retomar_contato', language: 'pt_BR' },
    };
    const text = mount(TemplateButtons).text();
    expect(text).toContain('Quero continuar');
    expect(text).toContain('Ligar');
  });

  it('shows 2 buttons and a "see all" toggle when there are more than 3', async () => {
    templates.push({
      name: 'catalogo',
      language: 'pt_BR',
      components: [
        {
          type: 'BUTTONS',
          buttons: [1, 2, 3, 4].map(n => ({
            type: 'QUICK_REPLY',
            text: `Opção ${n}`,
          })),
        },
      ],
    });
    additionalAttributes.value = {
      templateParams: { name: 'catalogo', language: 'pt_BR' },
    };
    const wrapper = mount(TemplateButtons);
    expect(wrapper.text()).toContain('Opção 2');
    expect(wrapper.text()).not.toContain('Opção 3');
    await wrapper
      .find('[data-testid="template-buttons-toggle"]')
      .trigger('click');
    expect(wrapper.text()).toContain('Opção 4');
  });

  it('renders nothing for a normal message or an unknown template', () => {
    additionalAttributes.value = {};
    expect(mount(TemplateButtons).find('[data-testid]').exists()).toBe(false);
    additionalAttributes.value = { templateParams: { name: 'apagado' } };
    expect(mount(TemplateButtons).find('[data-testid]').exists()).toBe(false);
  });
});

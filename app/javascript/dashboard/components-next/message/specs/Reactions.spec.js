import { mount } from '@vue/test-utils';
import Reactions from '../chips/Reactions.vue';

const mountReactions = reactions => mount(Reactions, { props: { reactions } });

describe('Reactions', () => {
  it('renders nothing without reactions', () => {
    expect(
      mountReactions({}).find('[data-testid="message-reactions"]').exists()
    ).toBe(false);
  });

  it('shows the customer and the team reaction', () => {
    const wrapper = mountReactions({ contact: '👍', business: '❤️' });

    expect(wrapper.find('[data-side="contact"]').text()).toBe('👍');
    expect(wrapper.find('[data-side="business"]').text()).toBe('❤️');
  });

  it('shows only the reaction that exists', () => {
    const wrapper = mountReactions({ business: '🙏' });

    expect(wrapper.find('[data-side="contact"]').exists()).toBe(false);
    expect(wrapper.find('[data-side="business"]').text()).toBe('🙏');
  });
});

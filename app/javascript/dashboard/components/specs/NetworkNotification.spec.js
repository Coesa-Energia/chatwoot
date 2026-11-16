import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import NetworkNotification from '../NetworkNotification.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ name: 'inbox_conversation' }),
}));

const mountBanner = () =>
  mount(NetworkNotification, {
    global: {
      mocks: { $t: key => key },
      stubs: {
        'fluent-icon': true,
        Button: true,
        // Render the banner directly so hiding is not delayed by the leave animation.
        transition: {
          render() {
            return this.$slots.default();
          },
        },
      },
    },
  });

const isBannerVisible = wrapper =>
  wrapper.find('.fixed').attributes('style') !== 'display: none;';

describe('NetworkNotification', () => {
  let wrapper;

  beforeEach(() => {
    vi.useFakeTimers();
    wrapper = mountBanner();
  });

  afterEach(() => {
    wrapper.unmount();
    vi.useRealTimers();
  });

  it('stays hidden when the socket drops and comes back within the grace period', async () => {
    emitter.emit(BUS_EVENTS.WEBSOCKET_DISCONNECT);
    vi.advanceTimersByTime(1500);
    emitter.emit(BUS_EVENTS.WEBSOCKET_RECONNECT);
    emitter.emit(BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED);
    vi.advanceTimersByTime(10000);
    await nextTick();

    expect(isBannerVisible(wrapper)).toBe(false);
  });

  it('warns when the socket stays down past the grace period', async () => {
    emitter.emit(BUS_EVENTS.WEBSOCKET_DISCONNECT);
    vi.advanceTimersByTime(4000);
    await nextTick();
    expect(isBannerVisible(wrapper)).toBe(false);

    // Further failed attempts do not push the warning back.
    emitter.emit(BUS_EVENTS.WEBSOCKET_DISCONNECT);
    vi.advanceTimersByTime(1000);
    await nextTick();
    expect(isBannerVisible(wrapper)).toBe(true);
    expect(wrapper.text()).toContain('NETWORK.NOTIFICATION.OFFLINE');
  });

  it('shows reconnecting and reconnected after a visible outage', async () => {
    emitter.emit(BUS_EVENTS.WEBSOCKET_DISCONNECT);
    vi.advanceTimersByTime(5000);
    emitter.emit(BUS_EVENTS.WEBSOCKET_RECONNECT);
    await nextTick();
    expect(wrapper.text()).toContain('NETWORK.NOTIFICATION.RECONNECTING');

    emitter.emit(BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED);
    await nextTick();
    expect(wrapper.text()).toContain('NETWORK.NOTIFICATION.RECONNECT_SUCCESS');

    vi.advanceTimersByTime(2000);
    await nextTick();
    expect(isBannerVisible(wrapper)).toBe(false);
  });

  it('warns right away when the browser goes offline', async () => {
    window.dispatchEvent(new Event('offline'));
    await nextTick();
    expect(isBannerVisible(wrapper)).toBe(true);
  });
});

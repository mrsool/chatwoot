import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import LiveSla from '../LiveSla.vue';

vi.mock('../components/ReportHeader.vue', () => ({
  default: { template: '<div />' },
}));

const setHidden = hidden => {
  Object.defineProperty(document, 'hidden', {
    value: hidden,
    configurable: true,
  });
  document.dispatchEvent(new Event('visibilitychange'));
};

const build = () => {
  const fetch = vi.fn();
  const noop = { namespaced: true, actions: { get: vi.fn() } };
  const store = createStore({
    modules: {
      liveSla: {
        namespaced: true,
        state: {},
        getters: {
          getRows: () => [],
          getSummary: () => null,
          getServerTime: () => 0,
          getFetchedAt: () => 0,
          getStaleSince: () => null,
        },
        actions: { fetch },
      },
      agents: noop,
      inboxes: noop,
      teams: noop,
      labels: noop,
      sla: noop,
    },
  });
  const wrapper = mount(LiveSla, {
    global: {
      plugins: [store],
      stubs: { LiveSlaFilters: true, LiveSlaTable: true, LiveSlaSummary: true },
    },
  });
  return { fetch, wrapper };
};

describe('LiveSla page', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    setHidden(false);
  });
  afterEach(() => {
    vi.useRealTimers();
    setHidden(false);
  });

  it('fetches on mount, polls every 5s and stops on unmount', async () => {
    const { fetch, wrapper } = build();
    expect(fetch).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(10000);
    expect(fetch).toHaveBeenCalledTimes(3);
    wrapper.unmount();
    await vi.advanceTimersByTimeAsync(20000);
    expect(fetch).toHaveBeenCalledTimes(3);
  });

  it('does not fetch while the document is hidden and refetches on return', async () => {
    const { fetch, wrapper } = build();
    fetch.mockClear();
    setHidden(true);
    await vi.advanceTimersByTimeAsync(20000);
    expect(fetch).not.toHaveBeenCalled();
    setHidden(false);
    expect(fetch).toHaveBeenCalledTimes(1);
    wrapper.unmount();
  });

  it('fetches immediately with the new filters when a filter changes', async () => {
    const { fetch, wrapper } = build();
    fetch.mockClear();
    wrapper
      .findComponent({ name: 'LiveSlaFilters' })
      .vm.$emit('change', { inbox_id: 2 });
    await wrapper.vm.$nextTick();
    expect(fetch).toHaveBeenCalledTimes(1);
    expect(fetch.mock.calls[0][1]).toEqual({ inbox_id: 2 });
    wrapper.unmount();
  });
});

import { ref } from 'vue';
import { shallowMount } from '@vue/test-utils';
import IdleAwayWatcher from '../IdleAwayWatcher.vue';
import { useAlert } from 'dashboard/composables';
import { useIdleAway } from 'dashboard/composables/useIdleAway';

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/useIdleAway', () => ({
  useIdleAway: vi.fn(() => ({
    isPromptOpen: false,
    secondsLeft: 60,
    confirmPresent: vi.fn(),
  })),
}));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: key => {
    const values = {
      getCurrentAccountId: 1,
      'accounts/getAccount': () => ({ settings: {} }),
      'awayReasons/getActive': [],
      getCurrentUserAvailability: 'online',
    };
    return ref(values[key]);
  },
}));

const mountWatcher = () => {
  shallowMount(IdleAwayWatcher);
  return useIdleAway.mock.calls.at(-1)[0].onError;
};

describe('IdleAwayWatcher', () => {
  beforeEach(() => vi.clearAllMocks());

  it('alerts with the server message when auto-away fails', () => {
    const onError = mountWatcher();
    onError(new Error('Away reason is inactive'));
    expect(useAlert).toHaveBeenCalledWith('Away reason is inactive');
  });

  it('alerts with the generic message when there is no server message', () => {
    const onError = mountWatcher();
    onError(new Error(''));
    expect(useAlert).toHaveBeenCalledWith('IDLE_AWAY.AUTO_AWAY_FAILED');
  });
});

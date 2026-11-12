import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import SidebarProfileMenuStatus from '../SidebarProfileMenuStatus.vue';
import { useAwayReasonPicker } from 'dashboard/composables/useAwayReasonPicker';

const dispatch = vi.fn();
let flagOn = false;
let availability = 'online';

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: key => {
    const values = {
      getCurrentUserAvailability: availability,
      getCurrentUserAwayReasonName: 'Prayer',
      getCurrentAccountId: 9,
      getCurrentUserAutoOffline: false,
      'accounts/isFeatureEnabledonAccount': () => flagOn,
    };
    return ref(values[key]);
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useImpersonation', () => ({
  useImpersonation: () => ({ isImpersonating: ref(false) }),
}));

const DropdownItem = {
  props: ['label'],
  emits: ['click'],
  template:
    '<li class="item" @click="$emit(\'click\')">{{ label }}<slot /></li>',
};

const mountStatus = () =>
  mount(SidebarProfileMenuStatus, {
    global: {
      mocks: { $t: key => key },
      stubs: {
        DropdownSection: { template: '<div><slot /></div>' },
        DropdownItem,
        DropdownContainer: {
          template:
            '<div><slot name="trigger" :toggle="() => {}" /><slot /></div>',
        },
        DropdownBody: { template: '<ul><slot /></ul>' },
        ToggleSwitch: true,
        Icon: true,
        Button: { template: '<button><slot /></button>' },
      },
      directives: { tooltip: () => {} },
    },
  });

const labels = wrapper => wrapper.findAll('.item').map(i => i.text());

describe('SidebarProfileMenuStatus', () => {
  beforeEach(() => {
    dispatch.mockClear();
    availability = 'online';
  });

  it('hides Away when fazaa_wfm is off', () => {
    flagOn = false;
    const wrapper = mountStatus();
    expect(
      labels(wrapper).some(l =>
        l.includes('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.AWAY')
      )
    ).toBe(false);
  });

  it('shows Away when fazaa_wfm is on', () => {
    flagOn = true;
    const wrapper = mountStatus();
    expect(
      labels(wrapper).some(l =>
        l.includes('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.AWAY')
      )
    ).toBe(true);
  });

  it('choosing Away requests the picker instead of saving', async () => {
    flagOn = true;
    const wrapper = mountStatus();
    const { isAwayReasonPickerOpen, closeAwayReasonPicker } =
      useAwayReasonPicker();
    closeAwayReasonPicker();
    expect(isAwayReasonPickerOpen.value).toBe(false);
    const away = wrapper
      .findAll('.item')
      .find(i => i.text() === 'PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.AWAY');
    await away.trigger('click');
    expect(dispatch).not.toHaveBeenCalled();
    expect(isAwayReasonPickerOpen.value).toBe(true);
  });

  it('keeps showing Away as active when fazaa_wfm is off, but not selectable', () => {
    flagOn = false;
    availability = 'away';
    const wrapper = mountStatus();
    expect(wrapper.find('button').text()).toContain(
      'PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.AWAY · Prayer'
    );
    const options = wrapper.findAll('ul .item').map(i => i.text());
    expect(options).not.toContain(
      'PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.AWAY'
    );
    expect(options).toContain(
      'PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.ONLINE'
    );
  });
});

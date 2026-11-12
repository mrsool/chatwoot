import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import AwayReasonPicker from '../AwayReasonPicker.vue';

const dispatch = vi.fn().mockResolvedValue();
const reasons = [
  { id: 5, name: 'Lunch', position: 1 },
  { id: 6, name: 'Prayer', position: 2 },
];

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: key => ref(key === 'getCurrentAccountId' ? 9 : reasons),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const mountPicker = () =>
  mount(AwayReasonPicker, {
    global: { mocks: { $t: key => key } },
  });

describe('AwayReasonPicker', () => {
  beforeEach(() => dispatch.mockClear());

  it('disables save until a reason is selected', async () => {
    const wrapper = mountPicker();
    const save = wrapper.find('[data-testid="away-save"]');
    expect(save.attributes('disabled')).toBeDefined();
    await wrapper.find('input[value="6"]').setValue(true);
    expect(save.attributes('disabled')).toBeUndefined();
  });

  it('dispatches updateAvailability with the selected reason', async () => {
    const wrapper = mountPicker();
    dispatch.mockClear();
    await wrapper.find('input[value="6"]').setValue(true);
    await wrapper.find('[data-testid="away-save"]').trigger('click');
    expect(dispatch).toHaveBeenCalledWith('updateAvailability', {
      availability: 'away',
      account_id: 9,
      away_reason_id: 6,
    });
  });

  it('cancel dispatches nothing and emits close', async () => {
    const wrapper = mountPicker();
    dispatch.mockClear();
    await wrapper.find('[data-testid="away-cancel"]').trigger('click');
    expect(dispatch).not.toHaveBeenCalled();
    expect(wrapper.emitted('close')).toBeTruthy();
  });
});

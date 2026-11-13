import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import Index from '../Index.vue';
import CompensationCapsAPI from 'dashboard/api/compensationCaps';
import { useAlert } from 'dashboard/composables';
import en from 'dashboard/i18n/locale/en/compensationCaps.json';

vi.mock('dashboard/api/compensationCaps', () => ({
  default: { get: vi.fn(), update: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  messages: { en },
});

const caps = (overrides = {}) => ({
  bad_grade_value_limit: 30,
  at_risk_value_limit: null,
  valuable_value_limit: 120.5,
  per_order_count_limit: 2,
  bad_grade_window_count_limit: null,
  at_risk_window_count_limit: 4,
  valuable_window_count_limit: 6,
  vip_window_count_limit: 10,
  window_days: 30,
  updated_at: '2026-11-13T10:00:00Z',
  updated_by: { id: 1, name: 'Sara Admin' },
  ...overrides,
});

const mountPage = async payload => {
  CompensationCapsAPI.get.mockResolvedValue({ data: { payload } });
  const wrapper = mount(Index, {
    global: {
      plugins: [i18n],
      stubs: { BaseSettingsHeader: true, 'fluent-icon': true },
    },
  });
  await flushPromises();
  return wrapper;
};
const input = (wrapper, key) => wrapper.find(`[data-testid="cap-${key}"]`);

describe('Compensation caps page', () => {
  beforeEach(() => vi.clearAllMocks());

  it('fills the 9 inputs; a nil cap is empty with the default placeholder', async () => {
    const wrapper = await mountPage(caps());
    expect(wrapper.findAll('input[type="number"]')).toHaveLength(9);
    expect(input(wrapper, 'bad_grade_value_limit').element.value).toBe('30');
    expect(input(wrapper, 'valuable_value_limit').element.value).toBe('120.5');
    expect(input(wrapper, 'window_days').element.value).toBe('30');
    const nil = input(wrapper, 'at_risk_value_limit');
    expect(nil.element.value).toBe('');
    expect(nil.attributes('placeholder')).toBe(
      en.COMPENSATION_CAPS.FORM.USE_DEFAULT
    );
    expect(wrapper.find('[data-testid="vip-unlimited"]').text()).toBe(
      en.COMPENSATION_CAPS.FORM.UNLIMITED
    );
  });

  it('submits numbers for filled fields and null for cleared ones', async () => {
    const wrapper = await mountPage(caps());
    CompensationCapsAPI.update.mockResolvedValue({ data: { payload: caps() } });
    await input(wrapper, 'bad_grade_value_limit').setValue('');
    await input(wrapper, 'per_order_count_limit').setValue('3');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(CompensationCapsAPI.update).toHaveBeenCalledWith({
      bad_grade_value_limit: null,
      at_risk_value_limit: null,
      valuable_value_limit: 120.5,
      per_order_count_limit: 3,
      bad_grade_window_count_limit: null,
      at_risk_window_count_limit: 4,
      valuable_window_count_limit: 6,
      vip_window_count_limit: 10,
      window_days: 30,
    });
  });

  it('shows inline errors and skips update for window_days 0 and fractional counts', async () => {
    const wrapper = await mountPage(caps());
    await input(wrapper, 'window_days').setValue('0');
    await input(wrapper, 'vip_window_count_limit').setValue('1.5');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(wrapper.find('[data-testid="error-window_days"]').exists()).toBe(
      true
    );
    expect(
      wrapper.find('[data-testid="error-vip_window_count_limit"]').exists()
    ).toBe(true);
    expect(CompensationCapsAPI.update).not.toHaveBeenCalled();
  });

  it('renders the last changed line when updated_by is present', async () => {
    const wrapper = await mountPage(caps());
    const line = wrapper.find('[data-testid="caps-last-changed"]');
    expect(line.exists()).toBe(true);
    expect(line.text()).toContain('Sara Admin');
    const none = await mountPage(caps({ updated_by: null, updated_at: null }));
    expect(none.find('[data-testid="caps-last-changed"]').exists()).toBe(false);
  });

  it('shows a success alert on save', async () => {
    const wrapper = await mountPage(caps());
    CompensationCapsAPI.update.mockResolvedValue({ data: { payload: caps() } });
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(useAlert).toHaveBeenCalledWith(en.COMPENSATION_CAPS.API.SUCCESS);
  });

  it('shows the server message on failure', async () => {
    const wrapper = await mountPage(caps());
    CompensationCapsAPI.update.mockRejectedValue({
      response: { data: { message: 'Window days is out of range' } },
    });
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(useAlert).toHaveBeenCalledWith('Window days is out of range');
  });
});

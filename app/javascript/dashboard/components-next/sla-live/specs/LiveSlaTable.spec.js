import { mount } from '@vue/test-utils';
import LiveSlaTable from '../LiveSlaTable.vue';

const push = vi.fn();
vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
  useRoute: () => ({ params: { accountId: '7' } }),
}));

const SERVER_TIME = 1000;
const NA = { state: 'na' };
const row = (id, worst, frt = NA) => ({
  conversation_id: id,
  display_id: id + 100,
  inbox: { id: 1, name: 'WA' },
  assignee: null,
  sla_policy: { id: 1, name: 'Gold' },
  labels: [],
  custom_attributes: {},
  timers: { frt, nrt: NA, rt: NA },
  worst_state: worst,
});

const mountTable = rows =>
  mount(LiveSlaTable, {
    props: {
      rows,
      serverTime: SERVER_TIME,
      fetchedAt: Date.now(),
      atRiskPercent: 20,
    },
  });

describe('LiveSlaTable', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    push.mockClear();
  });
  afterEach(() => vi.useRealTimers());

  it('renders rows in the order given, breached first', () => {
    const wrapper = mountTable([
      row(1, 'breached', {
        state: 'breached',
        due_at: SERVER_TIME - 5,
        threshold_seconds: 600,
      }),
      row(2, 'na'),
    ]);
    const ids = wrapper.findAll('[data-test="live-sla-row"]');
    expect(ids[0].text()).toContain('101');
    expect(ids[1].text()).toContain('102');
    expect(ids[1].find('[data-test="chip-frt"]').text()).toBe('–');
  });

  it('shows an at-risk chip with the countdown and flips to breached locally', async () => {
    const wrapper = mountTable([
      row(1, 'at_risk', {
        state: 'at_risk',
        due_at: SERVER_TIME + 30,
        threshold_seconds: 600,
      }),
    ]);
    const chip = () => wrapper.find('[data-test="chip-frt"]');
    expect(chip().text()).toBe('00:30');
    expect(chip().attributes('data-state')).toBe('at_risk');

    await vi.advanceTimersByTimeAsync(31000);
    expect(chip().attributes('data-state')).toBe('breached');
    expect(chip().text()).toBe('-00:01');
  });

  it('flips on_track to at_risk once under the threshold percentage', async () => {
    const wrapper = mountTable([
      row(1, 'on_track', {
        state: 'on_track',
        due_at: SERVER_TIME + 100,
        threshold_seconds: 300,
      }),
    ]);
    const chip = () => wrapper.find('[data-test="chip-frt"]');
    expect(chip().attributes('data-state')).toBe('on_track');
    await vi.advanceTimersByTimeAsync(41000); // 59s left < 20% of 300
    expect(chip().attributes('data-state')).toBe('at_risk');
  });

  it('formats long countdowns as h:mm:ss', () => {
    const wrapper = mountTable([
      row(1, 'on_track', {
        state: 'on_track',
        due_at: SERVER_TIME + 3725,
        threshold_seconds: 7200,
      }),
    ]);
    expect(wrapper.find('[data-test="chip-frt"]').text()).toBe('1:02:05');
  });

  it('opens the conversation on row click', async () => {
    const wrapper = mountTable([row(1, 'na')]);
    await wrapper.find('[data-test="live-sla-row"]').trigger('click');
    expect(push).toHaveBeenCalledWith('/app/accounts/7/conversations/101');
  });
});

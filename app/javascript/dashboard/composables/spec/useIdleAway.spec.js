import { effectScope, ref } from 'vue';
import { useIdleAway } from '../useIdleAway';

const KEY = 'fazaa:lastActivityAt';
const MIN = 60_000;

const makeStorage = () => {
  const map = new Map();
  return {
    getItem: k => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, String(v)),
  };
};

describe('useIdleAway', () => {
  let scope;
  let storage;
  let availability;
  let setAway;
  let timeoutMinutes;
  let onError;

  const start = () => {
    let api;
    scope = effectScope();
    scope.run(() => {
      api = useIdleAway({
        timeoutMinutes,
        reasonId: 7,
        getAvailability: () => availability.value,
        setAway,
        onError,
        now: () => Date.now(),
        storage,
      });
    });
    return api;
  };

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(1_000_000);
    storage = makeStorage();
    availability = ref('online');
    timeoutMinutes = ref(1);
    setAway = vi.fn().mockResolvedValue();
    onError = vi.fn();
  });

  afterEach(() => {
    scope?.stop();
    vi.useRealTimers();
  });

  it('does not prompt before the timeout and prompts at exactly the timeout', () => {
    const api = start();
    vi.advanceTimersByTime(MIN - 1000);
    expect(api.isPromptOpen.value).toBe(false);
    vi.advanceTimersByTime(1000);
    expect(api.isPromptOpen.value).toBe(true);
    expect(api.secondsLeft.value).toBe(60);
  });

  it('counts down and confirmPresent closes the prompt without going away', () => {
    const api = start();
    vi.advanceTimersByTime(MIN + 10_000);
    expect(api.secondsLeft.value).toBe(50);
    api.confirmPresent();
    expect(api.isPromptOpen.value).toBe(false);
    vi.advanceTimersByTime(59_000);
    expect(api.isPromptOpen.value).toBe(false);
    vi.advanceTimersByTime(MIN);
    expect(setAway).not.toHaveBeenCalled();
    expect(api.isPromptOpen.value).toBe(true);
  });

  it('calls setAway once with the reason when the countdown runs out', () => {
    setAway.mockImplementation(async () => {
      availability.value = 'away';
    });
    const api = start();
    vi.advanceTimersByTime(MIN + 60_000);
    expect(setAway).toHaveBeenCalledTimes(1);
    expect(setAway).toHaveBeenCalledWith(7);
    expect(api.isPromptOpen.value).toBe(false);
  });

  it('closes the prompt and resets the timer when setAway fails', async () => {
    setAway.mockRejectedValue(new Error('nope'));
    const api = start();
    vi.advanceTimersByTime(MIN + 60_000);
    await Promise.resolve();
    await Promise.resolve();
    expect(setAway).toHaveBeenCalledTimes(1);
    expect(api.isPromptOpen.value).toBe(false);
    vi.advanceTimersByTime(MIN - 1000);
    expect(api.isPromptOpen.value).toBe(false);
    expect(setAway).toHaveBeenCalledTimes(1);
  });

  it('reports a failed setAway through onError and still resets the timer', async () => {
    const failure = new Error('Away reason is inactive');
    setAway.mockRejectedValue(failure);
    start();
    vi.advanceTimersByTime(MIN + 60_000);
    await Promise.resolve();
    await Promise.resolve();
    expect(onError).toHaveBeenCalledTimes(1);
    expect(onError).toHaveBeenCalledWith(failure);
    expect(Number(storage.getItem(KEY))).toBe(Date.now());
  });

  it('does not call onError when setAway succeeds', async () => {
    start();
    vi.advanceTimersByTime(MIN + 60_000);
    await Promise.resolve();
    await Promise.resolve();
    expect(setAway).toHaveBeenCalledTimes(1);
    expect(onError).not.toHaveBeenCalled();
  });

  it('activity during the countdown closes the prompt', () => {
    const api = start();
    vi.advanceTimersByTime(MIN + 5000);
    window.dispatchEvent(new Event('mousemove'));
    expect(api.isPromptOpen.value).toBe(false);
    expect(Number(storage.getItem(KEY))).toBe(Date.now());
  });

  it('throttles activity writes to one per 5 seconds', () => {
    start();
    window.dispatchEvent(new Event('keydown'));
    const first = storage.getItem(KEY);
    vi.advanceTimersByTime(2000);
    window.dispatchEvent(new Event('keydown'));
    expect(storage.getItem(KEY)).toBe(first);
    vi.advanceTimersByTime(4000);
    window.dispatchEvent(new Event('keydown'));
    expect(storage.getItem(KEY)).not.toBe(first);
  });

  it('activity recorded by another tab keeps the prompt from opening', () => {
    const api = start();
    vi.advanceTimersByTime(MIN - 2000);
    storage.setItem(KEY, Date.now());
    vi.advanceTimersByTime(MIN - 3000);
    expect(api.isPromptOpen.value).toBe(false);
  });

  it('closes an open prompt when another tab records activity', () => {
    const api = start();
    vi.advanceTimersByTime(MIN + 5000);
    expect(api.isPromptOpen.value).toBe(true);
    storage.setItem(KEY, Date.now());
    window.dispatchEvent(new StorageEvent('storage', { key: KEY }));
    expect(api.isPromptOpen.value).toBe(false);
    vi.advanceTimersByTime(MIN);
    expect(setAway).not.toHaveBeenCalled();
  });

  it.each(['offline', 'away'])('runs no timer when %s', status => {
    availability.value = status;
    const api = start();
    expect(vi.getTimerCount()).toBe(0);
    vi.advanceTimersByTime(10 * MIN);
    expect(api.isPromptOpen.value).toBe(false);
  });

  it('runs no timer when idle is disabled', () => {
    timeoutMinutes.value = null;
    const api = start();
    expect(vi.getTimerCount()).toBe(0);
    vi.advanceTimersByTime(10 * MIN);
    expect(api.isPromptOpen.value).toBe(false);
    expect(setAway).not.toHaveBeenCalled();
  });

  it('stops the timer when availability changes to away, and cleans up on stop', async () => {
    const api = start();
    vi.advanceTimersByTime(MIN + 1000);
    availability.value = 'away';
    await Promise.resolve();
    expect(api.isPromptOpen.value).toBe(false);
    expect(vi.getTimerCount()).toBe(0);
    availability.value = 'online';
    await Promise.resolve();
    expect(vi.getTimerCount()).toBe(1);
    scope.stop();
    expect(vi.getTimerCount()).toBe(0);
  });

  it('refreshes activity on activation so a stale key does not prompt', async () => {
    storage.setItem(KEY, Date.now() - 10 * MIN);
    availability.value = 'away';
    const api = start();
    availability.value = 'online';
    await Promise.resolve();
    vi.advanceTimersByTime(1000);
    expect(api.isPromptOpen.value).toBe(false);
    expect(Number(storage.getItem(KEY))).toBeGreaterThan(Date.now() - 2000);
  });

  it('refreshes activity on load with a stale key', () => {
    storage.setItem(KEY, Date.now() - 10 * MIN);
    const api = start();
    vi.advanceTimersByTime(1000);
    expect(api.isPromptOpen.value).toBe(false);
  });

  it('ignores ticks while setAway is pending and calls it once', async () => {
    let resolve;
    setAway.mockImplementation(
      () =>
        new Promise(r => {
          resolve = r;
        })
    );
    const api = start();
    vi.advanceTimersByTime(MIN + 60_000);
    expect(setAway).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(10_000);
    expect(api.isPromptOpen.value).toBe(false);
    expect(setAway).toHaveBeenCalledTimes(1);
    resolve();
    await Promise.resolve();
    await Promise.resolve();
    vi.advanceTimersByTime(MIN - 2000);
    expect(api.isPromptOpen.value).toBe(false);
    expect(setAway).toHaveBeenCalledTimes(1);
  });
});

import { computed, ref, toValue, watch, onScopeDispose } from 'vue';

export const LAST_ACTIVITY_KEY = 'fazaa:lastActivityAt';
const ACTIVITY_THROTTLE_MS = 5000;
const COUNTDOWN_MS = 60_000;
const TICK_MS = 1000;
const ACTIVITY_EVENTS = [
  'mousemove',
  'mousedown',
  'keydown',
  'wheel',
  'touchstart',
  'focus',
];

/**
 * Idle detector. Opens a "Still there?" prompt after `timeoutMinutes` without
 * activity (shared across tabs through localStorage), then calls `setAway`
 * once if nobody confirms within 60s. Runs only while idle is enabled
 * (`timeoutMinutes` truthy) and the agent is online or busy. A failed
 * `setAway` is passed to `onError`; the idle clock restarts either way.
 */
export function useIdleAway({
  timeoutMinutes,
  reasonId,
  getAvailability,
  setAway,
  onError = () => {},
  now = Date.now,
  storage = window.localStorage,
}) {
  const isPromptOpen = ref(false);
  const secondsLeft = ref(COUNTDOWN_MS / 1000);
  let intervalId = null;
  let deadline = 0;
  let openedAt = 0;
  let lastWrite = 0;
  let inFlight = false;

  const readLastActivity = () => {
    try {
      return Number(storage.getItem(LAST_ACTIVITY_KEY)) || 0;
    } catch {
      return 0;
    }
  };

  const writeActivity = () => {
    lastWrite = now();
    try {
      storage.setItem(LAST_ACTIVITY_KEY, String(lastWrite));
    } catch {
      // storage unavailable; the timer then only sees this tab's last write
    }
  };

  const closePrompt = () => {
    isPromptOpen.value = false;
    secondsLeft.value = COUNTDOWN_MS / 1000;
  };

  const confirmPresent = () => {
    closePrompt();
    writeActivity();
  };

  const onActivity = () => {
    if (isPromptOpen.value) {
      confirmPresent();
    } else if (now() - lastWrite >= ACTIVITY_THROTTLE_MS) {
      writeActivity();
    }
  };

  const closeIfOtherTabActive = () => {
    if (isPromptOpen.value && readLastActivity() > openedAt) closePrompt();
  };

  const onStorage = event => {
    if (event.key === LAST_ACTIVITY_KEY) closeIfOtherTabActive();
  };

  const onVisibility = () => {
    if (document.visibilityState === 'visible') onActivity();
  };

  const goAway = async () => {
    closePrompt();
    inFlight = true;
    try {
      await setAway(toValue(reasonId));
    } catch (error) {
      // no retry; let the caller tell the agent
      onError(error);
    } finally {
      // restart the idle clock either way, then let ticks resume
      writeActivity();
      inFlight = false;
    }
  };

  const tick = () => {
    if (inFlight) return;
    const current = now();
    if (!isPromptOpen.value) {
      const idleMs = current - readLastActivity();
      if (idleMs >= toValue(timeoutMinutes) * 60_000) {
        isPromptOpen.value = true;
        openedAt = current;
        deadline = current + COUNTDOWN_MS;
        secondsLeft.value = COUNTDOWN_MS / 1000;
      }
      return;
    }
    closeIfOtherTabActive();
    if (!isPromptOpen.value) return;
    if (current >= deadline) {
      goAway();
    } else {
      secondsLeft.value = Math.ceil((deadline - current) / 1000);
    }
  };

  const attach = () => {
    ACTIVITY_EVENTS.forEach(e => window.addEventListener(e, onActivity));
    window.addEventListener('storage', onStorage);
    document.addEventListener('visibilitychange', onVisibility);
  };

  const detach = () => {
    ACTIVITY_EVENTS.forEach(e => window.removeEventListener(e, onActivity));
    window.removeEventListener('storage', onStorage);
    document.removeEventListener('visibilitychange', onVisibility);
  };

  const stop = () => {
    detach();
    clearInterval(intervalId);
    intervalId = null;
    closePrompt();
  };

  const isActive = computed(
    () =>
      !!toValue(timeoutMinutes) &&
      ['online', 'busy'].includes(getAvailability())
  );

  watch(
    isActive,
    active => {
      if (active) {
        if (intervalId) return;
        // Becoming active (page load, or back online after Away) starts a
        // fresh idle window; any older stored timestamp is stale.
        writeActivity();
        attach();
        intervalId = setInterval(tick, TICK_MS);
      } else {
        stop();
      }
    },
    { immediate: true }
  );

  onScopeDispose(stop);

  return { isPromptOpen, secondsLeft, confirmPresent };
}

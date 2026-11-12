import { onMounted, onBeforeUnmount } from 'vue';

// Runs `fn` every `ms` while the tab is visible. Pauses when hidden and runs
// `fn` immediately when the tab becomes visible again.
export const useVisibleInterval = (fn, ms, { immediate = false } = {}) => {
  let timer = null;
  let halted = false;

  const stop = () => {
    clearInterval(timer);
    timer = null;
  };
  const start = runNow => {
    stop();
    if (halted || document.hidden) return;
    if (runNow) fn();
    timer = setInterval(fn, ms);
  };
  const onVisibility = () => {
    if (document.hidden) stop();
    else start(true);
  };

  // Permanently stops the interval (it will not restart on visibility)
  const halt = () => {
    halted = true;
    stop();
  };

  onMounted(() => {
    start(immediate);
    document.addEventListener('visibilitychange', onVisibility);
  });
  onBeforeUnmount(() => {
    stop();
    document.removeEventListener('visibilitychange', onVisibility);
  });

  return { halt };
};

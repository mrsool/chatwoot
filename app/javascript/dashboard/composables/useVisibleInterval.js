import { onMounted, onBeforeUnmount } from 'vue';

// Runs `fn` every `ms` while the tab is visible. Pauses when hidden and runs
// `fn` immediately when the tab becomes visible again.
export const useVisibleInterval = (fn, ms, { immediate = false } = {}) => {
  let timer = null;

  const stop = () => {
    clearInterval(timer);
    timer = null;
  };
  const start = runNow => {
    stop();
    if (document.hidden) return;
    if (runNow) fn();
    timer = setInterval(fn, ms);
  };
  const onVisibility = () => {
    if (document.hidden) stop();
    else start(true);
  };

  onMounted(() => {
    start(immediate);
    document.addEventListener('visibilitychange', onVisibility);
  });
  onBeforeUnmount(() => {
    stop();
    document.removeEventListener('visibilitychange', onVisibility);
  });
};

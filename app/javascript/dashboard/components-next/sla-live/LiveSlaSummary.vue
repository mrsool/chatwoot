<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  summary: { type: Object, default: null },
  staleSince: { type: Number, default: null },
});

const { t } = useI18n();

const hitRate = computed(() => {
  const rate = props.summary?.hit_rate;
  return rate === null || rate === undefined
    ? '–'
    : `${Math.round(rate * 100)}%`;
});
const staleTime = computed(() =>
  props.staleSince
    ? new Date(props.staleSince).toLocaleTimeString([], { hour12: false })
    : ''
);
</script>

<template>
  <div class="flex flex-wrap items-center gap-4">
    <div class="flex flex-col px-4 py-3 rounded-lg bg-n-alpha-1 min-w-32">
      <span class="text-xs text-n-slate-11">{{ t('LIVE_SLA.BREACHED') }}</span>
      <span
        data-test="summary-breached"
        class="text-2xl font-medium text-n-ruby-11"
      >
        {{ summary?.breached ?? '–' }}
      </span>
    </div>
    <div class="flex flex-col px-4 py-3 rounded-lg bg-n-alpha-1 min-w-32">
      <span class="text-xs text-n-slate-11">{{ t('LIVE_SLA.AT_RISK') }}</span>
      <span
        data-test="summary-at-risk"
        class="text-2xl font-medium text-n-amber-11"
      >
        {{ summary?.at_risk ?? '–' }}
      </span>
    </div>
    <div class="flex flex-col px-4 py-3 rounded-lg bg-n-alpha-1 min-w-32">
      <span class="text-xs text-n-slate-11">
        {{ t('LIVE_SLA.HIT_RATE') }}
        <template v-if="summary?.window_hours">
          ({{ t('LIVE_SLA.WINDOW_HOURS', { hours: summary.window_hours }) }})
        </template>
      </span>
      <span
        data-test="summary-hit-rate"
        class="text-2xl font-medium text-n-slate-12"
      >
        {{ hitRate }}
      </span>
    </div>
    <span
      v-if="staleSince"
      data-test="stale-badge"
      class="px-2 py-1 text-xs rounded bg-n-amber-3 text-n-amber-11"
    >
      {{ t('LIVE_SLA.STALE_SINCE') }} {{ staleTime }}
    </span>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useVisibleInterval } from 'dashboard/composables/useVisibleInterval';
import ReportHeader from './components/ReportHeader.vue';
import LiveSlaSummary from 'dashboard/components-next/sla-live/LiveSlaSummary.vue';
import LiveSlaTable from 'dashboard/components-next/sla-live/LiveSlaTable.vue';
import LiveSlaFilters from 'dashboard/components-next/sla-live/LiveSlaFilters.vue';

const POLL_MS = 5000;

const { t } = useI18n();
const store = useStore();
const rows = useMapGetter('liveSla/getRows');
const summary = useMapGetter('liveSla/getSummary');
const serverTime = useMapGetter('liveSla/getServerTime');
const fetchedAt = useMapGetter('liveSla/getFetchedAt');
const staleSince = useMapGetter('liveSla/getStaleSince');
const forbidden = useMapGetter('liveSla/getForbidden');

const filters = ref({});
const fetchLive = () => store.dispatch('liveSla/fetch', filters.value);

store.dispatch('liveSla/resetForbidden');
['agents', 'inboxes', 'teams', 'labels', 'sla'].forEach(name =>
  store.dispatch(`${name}/get`)
);
const { halt } = useVisibleInterval(fetchLive, POLL_MS, { immediate: true });

watch(forbidden, isForbidden => {
  if (isForbidden) halt();
});

const onFilterChange = params => {
  filters.value = params;
  fetchLive();
};
</script>

<template>
  <ReportHeader :header-title="t('LIVE_SLA.TITLE')" />
  <div class="flex flex-col flex-1 gap-6">
    <p v-if="forbidden" data-test="forbidden" class="text-n-ruby-11">
      {{ t('LIVE_SLA.FORBIDDEN') }}
    </p>
    <LiveSlaFilters @change="onFilterChange" />
    <LiveSlaSummary :summary="summary" :stale-since="staleSince" />
    <LiveSlaTable
      :rows="rows"
      :server-time="serverTime"
      :fetched-at="fetchedAt"
      :at-risk-percent="summary?.at_risk_percent ?? 20"
    />
  </div>
</template>

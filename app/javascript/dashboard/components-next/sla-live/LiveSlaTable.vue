<script setup>
import { ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { useVisibleInterval } from 'dashboard/composables/useVisibleInterval';

const props = defineProps({
  rows: { type: Array, default: () => [] },
  serverTime: { type: Number, default: 0 },
  fetchedAt: { type: Number, default: 0 },
  atRiskPercent: { type: Number, default: 20 },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const TIMERS = ['frt', 'nrt', 'rt'];
const now = ref(Date.now());
watch(
  () => props.fetchedAt,
  () => {
    now.value = Date.now();
  }
);
useVisibleInterval(() => {
  now.value = Date.now();
}, 1000);

const pad = n => String(n).padStart(2, '0');
const formatSeconds = total => {
  const seconds = Math.abs(Math.floor(total));
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
};

const chipFor = timer => {
  if (!timer || timer.state === 'na') return { state: 'na', text: '–' };
  const elapsed = Math.max(0, (now.value - props.fetchedAt) / 1000);
  const remaining = timer.due_at - (props.serverTime + elapsed);
  const atRiskBelow = (timer.threshold_seconds * props.atRiskPercent) / 100;

  let state = 'on_track';
  if (timer.state === 'breached' || remaining <= 0) state = 'breached';
  else if (timer.state === 'at_risk' || remaining < atRiskBelow)
    state = 'at_risk';

  const text =
    remaining <= 0 ? `-${formatSeconds(remaining)}` : formatSeconds(remaining);
  return { state, text };
};

const CHIP_CLASSES = {
  breached: 'bg-n-ruby-3 text-n-ruby-11',
  at_risk: 'bg-n-amber-3 text-n-amber-11',
  on_track: 'bg-n-teal-3 text-n-teal-11',
  na: 'bg-n-alpha-1 text-n-slate-11',
};

const openConversation = row => {
  router.push(
    frontendURL(
      conversationUrl({
        accountId: route.params.accountId,
        id: row.display_id,
      })
    )
  );
};
</script>

<template>
  <table class="w-full text-sm text-start">
    <thead>
      <tr class="text-n-slate-11">
        <th class="p-2 text-start">{{ t('LIVE_SLA.TABLE.CONVERSATION') }}</th>
        <th class="p-2 text-start">{{ t('LIVE_SLA.TABLE.INBOX') }}</th>
        <th class="p-2 text-start">{{ t('LIVE_SLA.TABLE.ASSIGNEE') }}</th>
        <th class="p-2 text-start">{{ t('LIVE_SLA.TABLE.POLICY') }}</th>
        <th v-for="timer in TIMERS" :key="timer" class="p-2 text-start">
          {{ t(`LIVE_SLA.TIMERS.${timer.toUpperCase()}`) }}
        </th>
      </tr>
    </thead>
    <tbody>
      <tr
        v-for="row in rows"
        :key="row.conversation_id"
        data-test="live-sla-row"
        class="cursor-pointer hover:bg-n-alpha-1"
        @click="openConversation(row)"
      >
        <td class="p-2">#{{ row.display_id }}</td>
        <td class="p-2">{{ row.inbox?.name }}</td>
        <td class="p-2">{{ row.assignee?.name || '–' }}</td>
        <td class="p-2">{{ row.sla_policy?.name }}</td>
        <td v-for="timer in TIMERS" :key="timer" class="p-2">
          <span
            :data-test="`chip-${timer}`"
            :data-state="chipFor(row.timers[timer]).state"
            class="px-2 py-0.5 rounded tabular-nums"
            :class="CHIP_CLASSES[chipFor(row.timers[timer]).state]"
          >
            {{ chipFor(row.timers[timer]).text }}
          </span>
        </td>
      </tr>
      <tr v-if="!rows.length">
        <td colspan="7" class="p-6 text-center text-n-slate-11">
          {{ t('LIVE_SLA.EMPTY') }}
        </td>
      </tr>
    </tbody>
  </table>
</template>

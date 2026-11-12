<script setup>
import { computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useIdleAway } from 'dashboard/composables/useIdleAway';
import StillThereModal from './StillThereModal.vue';

const store = useStore();
const accountId = useMapGetter('getCurrentAccountId');
const getAccount = useMapGetter('accounts/getAccount');
const activeReasons = useMapGetter('awayReasons/getActive');
const availability = useMapGetter('getCurrentUserAvailability');

const settings = computed(
  () => getAccount.value(accountId.value)?.settings || {}
);
const reasonId = computed(() => settings.value.idle_away_reason_id);

// Mirrors Account#fazaa_idle_enabled?: timeout set, and its reason still active
const timeoutMinutes = computed(() => {
  const reasonIsActive = activeReasons.value.some(r => r.id === reasonId.value);
  return reasonId.value && reasonIsActive
    ? settings.value.idle_away_timeout_minutes || null
    : null;
});

onMounted(() => store.dispatch('awayReasons/get'));

const { isPromptOpen, secondsLeft, confirmPresent } = useIdleAway({
  timeoutMinutes,
  reasonId,
  getAvailability: () => availability.value,
  setAway: id =>
    store.dispatch('updateAvailability', {
      availability: 'away',
      account_id: accountId.value,
      away_reason_id: id,
    }),
});
</script>

<template>
  <StillThereModal
    :show="isPromptOpen"
    :seconds-left="secondsLeft"
    @confirm="confirmPresent"
  />
</template>

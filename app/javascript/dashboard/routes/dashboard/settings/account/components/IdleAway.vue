<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import Switch from 'next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const store = useStore();
const { currentAccount, updateAccount } = useAccount();
const reasons = useMapGetter('awayReasons/getActive');

const isEnabled = ref(false);
const minutes = ref(null);
const reasonId = ref(null);
const isSubmitting = ref(false);

const isValid = computed(
  () =>
    Number.isInteger(minutes.value) &&
    minutes.value >= 1 &&
    minutes.value <= 240 &&
    !!reasonId.value
);

watch(
  currentAccount,
  account => {
    const { idle_away_timeout_minutes: m, idle_away_reason_id: r } =
      account?.settings || {};
    minutes.value = m ?? null;
    reasonId.value = r ?? null;
    isEnabled.value = !!m;
  },
  { immediate: true, deep: true }
);

onMounted(() => store.dispatch('awayReasons/get'));

const save = async settings => {
  isSubmitting.value = true;
  try {
    await updateAccount(settings, { silent: true });
    useAlert(t('IDLE_AWAY.API.SUCCESS'));
  } catch (error) {
    useAlert(t('IDLE_AWAY.API.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

const handleSubmit = () => {
  if (!isValid.value) {
    useAlert(t('IDLE_AWAY.VALIDATION'));
    return;
  }
  save({
    idle_away_timeout_minutes: minutes.value,
    idle_away_reason_id: reasonId.value,
  });
};

const toggle = () => {
  if (isEnabled.value) return;
  minutes.value = null;
  reasonId.value = null;
  save({ idle_away_timeout_minutes: null, idle_away_reason_id: null });
};
</script>

<template>
  <div
    class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2 divide-y divide-n-weak"
  >
    <div class="flex flex-col gap-2 items-start px-5 py-4">
      <div class="flex justify-between items-center w-full">
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('IDLE_AWAY.TITLE') }}
        </h3>
        <Switch v-model="isEnabled" @change="toggle" />
      </div>
      <p class="mb-0 text-body-para text-n-slate-11">
        {{ t('IDLE_AWAY.NOTE') }}
      </p>
    </div>
    <div v-if="isEnabled" class="px-5 py-4">
      <form class="grid gap-5" @submit.prevent="handleSubmit">
        <WithLabel
          name="idle-away-minutes"
          :label="t('IDLE_AWAY.MINUTES.LABEL')"
          :help-message="t('IDLE_AWAY.MINUTES.HELP')"
        >
          <input
            v-model.number="minutes"
            type="number"
            min="1"
            max="240"
            class="w-full !mb-0 text-sm"
          />
        </WithLabel>
        <WithLabel
          name="idle-away-reason"
          :label="t('IDLE_AWAY.REASON.LABEL')"
          :help-message="t('IDLE_AWAY.REASON.HELP')"
        >
          <select v-model="reasonId" class="w-full !mb-0 text-sm">
            <option :value="null" disabled>
              {{ t('IDLE_AWAY.REASON.PLACEHOLDER') }}
            </option>
            <option v-for="r in reasons" :key="r.id" :value="r.id">
              {{ r.name }}
            </option>
          </select>
        </WithLabel>
        <div class="flex gap-2">
          <NextButton
            blue
            type="submit"
            :is-loading="isSubmitting"
            :label="t('IDLE_AWAY.SAVE')"
          />
        </div>
      </form>
    </div>
  </div>
</template>

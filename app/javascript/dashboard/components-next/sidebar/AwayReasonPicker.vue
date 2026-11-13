<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'next/button/Button.vue';

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();
const reasons = useMapGetter('awayReasons/getActive');
const currentAccountId = useMapGetter('getCurrentAccountId');

const selectedReasonId = ref(null);
const isSaving = ref(false);

onMounted(() => {
  store.dispatch('awayReasons/get');
});

const save = async () => {
  if (!selectedReasonId.value || isSaving.value) return;
  isSaving.value = true;
  try {
    await store.dispatch('updateAvailability', {
      availability: 'away',
      account_id: currentAccountId.value,
      away_reason_id: selectedReasonId.value,
    });
    emit('close');
  } catch (error) {
    useAlert(error.message || t('AWAY_REASONS.PICKER.ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('AWAY_REASONS.PICKER.TITLE')"
      :header-content="$t('AWAY_REASONS.PICKER.DESCRIPTION')"
    />
    <div class="flex flex-col gap-2 p-6 pt-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('AWAY_REASONS.PICKER.SELECT_REASON') }}
      </span>
      <p v-if="!reasons.length" class="text-sm text-n-slate-11">
        {{ $t('AWAY_REASONS.PICKER.EMPTY') }}
      </p>
      <label
        v-for="reason in reasons"
        :key="reason.id"
        class="flex items-center gap-2 px-3 py-2 text-sm border rounded-xl cursor-pointer border-n-weak text-n-slate-12"
      >
        <input
          v-model="selectedReasonId"
          type="radio"
          name="away-reason"
          class="m-0"
          :value="reason.id"
        />
        {{ reason.name }}
      </label>
      <div class="flex items-center justify-end gap-2 mt-4">
        <Button
          data-testid="away-cancel"
          faded
          slate
          :label="$t('AWAY_REASONS.PICKER.CANCEL')"
          @click="emit('close')"
        />
        <Button
          data-testid="away-save"
          :label="$t('AWAY_REASONS.PICKER.SAVE')"
          :disabled="!selectedReasonId"
          :is-loading="isSaving"
          @click="save"
        />
      </div>
    </div>
  </div>
</template>

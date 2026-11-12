<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AwayReasonForm from './AwayReasonForm.vue';

const { t } = useI18n();
const store = useStore();
const reasons = useMapGetter('awayReasons/getAwayReasons');
const uiFlags = useMapGetter('awayReasons/getUIFlags');

const showForm = ref(false);
const selectedReason = ref(null);

// Admin view lists inactive reasons too, ordered by position
const sortedReasons = computed(() =>
  [...reasons.value].sort((a, b) => a.position - b.position)
);
const nextPosition = computed(
  () => Math.max(0, ...reasons.value.map(r => r.position)) + 1
);

const tableHeaders = computed(() => [
  t('AWAY_REASONS.LIST.TABLE_HEADER.NAME'),
  t('AWAY_REASONS.LIST.TABLE_HEADER.STATUS'),
  t('AWAY_REASONS.LIST.TABLE_HEADER.ORDER'),
  t('INTEGRATION_APPS.LIST.ACTIONS'),
]);

onMounted(() => store.dispatch('awayReasons/get', { all: true }));

const openForm = reason => {
  selectedReason.value = reason;
  showForm.value = true;
};
const closeForm = () => {
  showForm.value = false;
  selectedReason.value = null;
};

const run = async (action, payload, successMessage) => {
  try {
    await store.dispatch(action, payload);
    if (successMessage) useAlert(successMessage);
  } catch (error) {
    useAlert(error.message || t('AWAY_REASONS.API.UPDATE_ERROR'));
  }
};

const deactivate = reason =>
  run(
    'awayReasons/deactivate',
    reason.id,
    t('AWAY_REASONS.API.DEACTIVATE_SUCCESS')
  );
const reactivate = reason =>
  run(
    'awayReasons/update',
    { id: reason.id, active: true },
    t('AWAY_REASONS.API.REACTIVATE_SUCCESS')
  );

// Swap positions with the neighbour so positions stay unique and stable
const move = async (index, offset) => {
  const current = sortedReasons.value[index];
  const neighbour = sortedReasons.value[index + offset];
  if (!neighbour) return;
  await run('awayReasons/update', {
    id: current.id,
    position: neighbour.position,
  });
  await run('awayReasons/update', {
    id: neighbour.id,
    position: current.position,
  });
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('AWAY_REASONS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('AWAY_REASONS.HEADER')"
        :description="$t('AWAY_REASONS.DESCRIPTION')"
        feature-name="away_reasons"
      >
        <template v-if="reasons.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('AWAY_REASONS.COUNT', { n: reasons.length }) }}
          </span>
        </template>
        <template #actions>
          <NextButton
            :label="$t('AWAY_REASONS.ADD_ACTION')"
            size="sm"
            @click="openForm(null)"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="sortedReasons"
        :no-data-message="!reasons.length ? $t('AWAY_REASONS.LIST.404') : ''"
      >
        <template #row="{ items }">
          <BaseTableRow v-for="reason in items" :key="reason.id" :item="reason">
            <template #default>
              <BaseTableCell>
                <span
                  class="text-body-main truncate"
                  :class="reason.active ? 'text-n-slate-12' : 'text-n-slate-10'"
                >
                  {{ reason.name }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="w-32">
                <WootLabel
                  :label="
                    reason.active
                      ? $t('AWAY_REASONS.LIST.ACTIVE')
                      : $t('AWAY_REASONS.LIST.INACTIVE')
                  "
                  :color="reason.active ? 'teal' : 'slate'"
                  compact
                />
              </BaseTableCell>
              <BaseTableCell class="w-24">
                <div class="flex gap-1">
                  <NextButton
                    v-tooltip.top="$t('AWAY_REASONS.LIST.MOVE_UP')"
                    icon="i-lucide-arrow-up"
                    slate
                    sm
                    :disabled="
                      items.indexOf(reason) === 0 || uiFlags.isUpdating
                    "
                    @click="move(items.indexOf(reason), -1)"
                  />
                  <NextButton
                    v-tooltip.top="$t('AWAY_REASONS.LIST.MOVE_DOWN')"
                    icon="i-lucide-arrow-down"
                    slate
                    sm
                    :disabled="
                      items.indexOf(reason) === items.length - 1 ||
                      uiFlags.isUpdating
                    "
                    @click="move(items.indexOf(reason), 1)"
                  />
                </div>
              </BaseTableCell>
              <BaseTableCell align="end" class="w-48">
                <div class="flex justify-end gap-1">
                  <NextButton
                    v-tooltip.top="$t('AWAY_REASONS.EDIT')"
                    icon="i-lucide-pen"
                    slate
                    sm
                    @click="openForm(reason)"
                  />
                  <NextButton
                    v-if="reason.active"
                    :label="$t('AWAY_REASONS.DEACTIVATE')"
                    slate
                    faded
                    sm
                    :disabled="uiFlags.isUpdating"
                    @click="deactivate(reason)"
                  />
                  <NextButton
                    v-else
                    :label="$t('AWAY_REASONS.REACTIVATE')"
                    slate
                    faded
                    sm
                    :disabled="uiFlags.isUpdating"
                    @click="reactivate(reason)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>

      <woot-modal v-model:show="showForm" :on-close="closeForm">
        <AwayReasonForm
          :reason="selectedReason"
          :next-position="nextPosition"
          @close="closeForm"
        />
      </woot-modal>
    </template>
  </SettingsLayout>
</template>

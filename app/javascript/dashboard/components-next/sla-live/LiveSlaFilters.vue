<script setup>
import { reactive, watch } from 'vue';
import { useDebounceFn } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';

const emit = defineEmits(['change']);

const { t } = useI18n();
const inboxes = useMapGetter('inboxes/getInboxes');
const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');
const labels = useMapGetter('labels/getLabels');
const policies = useMapGetter('sla/getSLA');

const filters = reactive({
  inbox_id: '',
  team_id: '',
  assignee_id: '',
  label: '',
  sla_policy_id: '',
  cr_code: '',
  country: '',
});

const emitChange = () => emit('change', { ...filters });
const emitChangeDebounced = useDebounceFn(emitChange, 400);
const TEXT_KEYS = ['cr_code', 'country'];

TEXT_KEYS.forEach(key => watch(() => filters[key], emitChangeDebounced));
watch(
  () => Object.entries(filters).filter(([k]) => !TEXT_KEYS.includes(k)),
  emitChange
);

const SELECTS = [
  {
    key: 'inbox_id',
    label: 'INBOX',
    items: inboxes,
    text: 'name',
    value: 'id',
  },
  { key: 'team_id', label: 'TEAM', items: teams, text: 'name', value: 'id' },
  {
    key: 'assignee_id',
    label: 'ASSIGNEE',
    items: agents,
    text: 'name',
    value: 'id',
  },
  {
    key: 'label',
    label: 'LABEL',
    items: labels,
    text: 'title',
    value: 'title',
  },
  {
    key: 'sla_policy_id',
    label: 'POLICY',
    items: policies,
    text: 'name',
    value: 'id',
  },
];
</script>

<template>
  <div class="flex flex-wrap items-center gap-3">
    <select
      v-for="select in SELECTS"
      :key="select.key"
      v-model="filters[select.key]"
      :aria-label="t(`LIVE_SLA.FILTERS.${select.label}`)"
      class="!mb-0 !w-auto"
    >
      <option value="">{{ t(`LIVE_SLA.FILTERS.${select.label}`) }}</option>
      <option
        v-for="item in select.items.value"
        :key="item[select.value]"
        :value="item[select.value]"
      >
        {{ item[select.text] }}
      </option>
    </select>
    <input
      v-model.trim="filters.cr_code"
      type="text"
      class="!mb-0 !w-40"
      :placeholder="t('LIVE_SLA.FILTERS.CR_CODE')"
    />
    <input
      v-model.trim="filters.country"
      type="text"
      class="!mb-0 !w-40"
      :placeholder="t('LIVE_SLA.FILTERS.COUNTRY')"
    />
  </div>
</template>

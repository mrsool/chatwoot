<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CompensationCapsAPI from 'dashboard/api/compensationCaps';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';

// min/max mirror the backend cap contract; blank = use MBO's default
const FIELDS = {
  bad_grade_value_limit: { min: 0, max: 100000, integer: false },
  at_risk_value_limit: { min: 0, max: 100000, integer: false },
  valuable_value_limit: { min: 0, max: 100000, integer: false },
  per_order_count_limit: { min: 0, max: 100, integer: true },
  bad_grade_window_count_limit: { min: 0, max: 1000, integer: true },
  at_risk_window_count_limit: { min: 0, max: 1000, integer: true },
  valuable_window_count_limit: { min: 0, max: 1000, integer: true },
  vip_window_count_limit: { min: 0, max: 1000, integer: true },
  window_days: { min: 1, max: 365, integer: true },
};
const KEYS = Object.keys(FIELDS);

const SECTIONS = [
  {
    id: 'value',
    prefix: 'VALUE',
    keys: [
      'bad_grade_value_limit',
      'at_risk_value_limit',
      'valuable_value_limit',
    ],
    vip: true,
  },
  { id: 'per-order', prefix: 'PER_ORDER', keys: ['per_order_count_limit'] },
  {
    id: 'window',
    prefix: 'WINDOW',
    keys: [
      'bad_grade_window_count_limit',
      'at_risk_window_count_limit',
      'valuable_window_count_limit',
      'vip_window_count_limit',
      'window_days',
    ],
  },
];

const { t } = useI18n();

const form = reactive(Object.fromEntries(KEYS.map(key => [key, ''])));
const errors = reactive({});
const isLoading = ref(true);
const isSubmitting = ref(false);
const updatedAt = ref(null);
const updatedBy = ref(null);

const lastChanged = computed(() => {
  if (!updatedBy.value) return '';
  return t('COMPENSATION_CAPS.LAST_CHANGED', {
    name: updatedBy.value.name,
    date: updatedAt.value ? new Date(updatedAt.value).toLocaleString() : '',
  });
});

const fieldLabel = key => t(`COMPENSATION_CAPS.FIELDS.${key.toUpperCase()}`);

const applyPayload = payload => {
  KEYS.forEach(key => {
    form[key] = payload[key] ?? '';
  });
  updatedAt.value = payload.updated_at || null;
  updatedBy.value = payload.updated_by || null;
};

const isBlank = value => value === '' || value === null || value === undefined;

const validate = () => {
  KEYS.forEach(key => delete errors[key]);
  KEYS.forEach(key => {
    const value = form[key];
    if (isBlank(value)) return;
    const { min, max, integer } = FIELDS[key];
    const number = Number(value);
    if (
      !Number.isFinite(number) ||
      (integer && !Number.isInteger(number)) ||
      number < min ||
      number > max
    ) {
      errors[key] = t(
        integer
          ? 'COMPENSATION_CAPS.VALIDATION.INTEGER_RANGE'
          : 'COMPENSATION_CAPS.VALIDATION.NUMBER_RANGE',
        { min, max }
      );
    }
  });
  return Object.keys(errors).length === 0;
};

const errorMessage = error =>
  error?.response?.data?.message || t('COMPENSATION_CAPS.API.ERROR');

onMounted(async () => {
  try {
    const { data } = await CompensationCapsAPI.get();
    applyPayload(data.payload);
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isLoading.value = false;
  }
});

const handleSubmit = async () => {
  if (!validate()) return;
  isSubmitting.value = true;
  try {
    // null clears a cap so MBO falls back to its default
    const payload = Object.fromEntries(
      KEYS.map(key => [key, isBlank(form[key]) ? null : Number(form[key])])
    );
    const { data } = await CompensationCapsAPI.update(payload);
    applyPayload(data.payload);
    useAlert(t('COMPENSATION_CAPS.API.SUCCESS'));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('COMPENSATION_CAPS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('COMPENSATION_CAPS.HEADER')"
        :description="t('COMPENSATION_CAPS.DESCRIPTION')"
        feature-name="compensation_caps"
      />
    </template>
    <template #body>
      <form class="grid gap-6 max-w-2xl" @submit.prevent="handleSubmit">
        <p
          v-if="lastChanged"
          data-testid="caps-last-changed"
          class="mb-0 text-body-para text-n-slate-11"
        >
          {{ lastChanged }}
        </p>
        <section
          v-for="section in SECTIONS"
          :key="section.id"
          class="flex flex-col gap-4 p-5 outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
        >
          <div class="flex flex-col gap-1">
            <h3 class="mb-0 text-heading-2 text-n-slate-12">
              {{ t(`COMPENSATION_CAPS.SECTIONS.${section.prefix}.TITLE`) }}
            </h3>
            <p
              v-if="section.prefix === 'VALUE'"
              class="mb-0 text-body-para text-n-slate-11"
            >
              {{ t('COMPENSATION_CAPS.SECTIONS.VALUE.HELP') }}
            </p>
          </div>
          <div v-for="key in section.keys" :key="key">
            <WithLabel :name="key" :label="fieldLabel(key)">
              <input
                :id="key"
                v-model="form[key]"
                :data-testid="`cap-${key}`"
                type="number"
                step="any"
                :min="FIELDS[key].min"
                :max="FIELDS[key].max"
                :placeholder="t('COMPENSATION_CAPS.FORM.USE_DEFAULT')"
                class="w-full !mb-0 text-sm"
              />
            </WithLabel>
            <p
              v-if="errors[key]"
              :data-testid="`error-${key}`"
              class="mt-1 mb-0 text-xs text-n-ruby-9"
            >
              {{ errors[key] }}
            </p>
          </div>
          <div v-if="section.vip" class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('COMPENSATION_CAPS.FIELDS.VIP_VALUE_LIMIT') }}
            </span>
            <span class="text-sm text-n-slate-11" data-testid="vip-unlimited">
              {{ t('COMPENSATION_CAPS.FORM.UNLIMITED') }}
            </span>
          </div>
        </section>
        <div class="flex gap-2">
          <NextButton
            blue
            type="submit"
            data-testid="caps-save"
            :is-loading="isSubmitting"
            :label="t('COMPENSATION_CAPS.FORM.SAVE')"
          />
        </div>
      </form>
    </template>
  </SettingsLayout>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  // When present the form renames this reason instead of creating one
  reason: { type: Object, default: null },
  // Position for a newly created reason (appended last)
  nextPosition: { type: Number, default: 1 },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();
const uiFlags = useMapGetter('awayReasons/getUIFlags');

const name = ref(props.reason?.name || '');
const touched = ref(false);

const isEdit = computed(() => !!props.reason);
const isSaving = computed(() =>
  isEdit.value ? uiFlags.value.isUpdating : uiFlags.value.isCreating
);
const nameError = computed(() =>
  touched.value && !name.value.trim()
    ? t('AWAY_REASONS.FORM.NAME.REQUIRED_ERROR')
    : ''
);

const onSubmit = async () => {
  touched.value = true;
  const trimmed = name.value.trim();
  if (!trimmed) return;
  try {
    if (isEdit.value) {
      await store.dispatch('awayReasons/update', {
        id: props.reason.id,
        name: trimmed,
      });
      useAlert(t('AWAY_REASONS.API.UPDATE_SUCCESS'));
    } else {
      await store.dispatch('awayReasons/create', {
        name: trimmed,
        position: props.nextPosition,
      });
      useAlert(t('AWAY_REASONS.API.ADD_SUCCESS'));
    }
    emit('close');
  } catch (error) {
    useAlert(
      error.message ||
        (isEdit.value
          ? t('AWAY_REASONS.API.UPDATE_ERROR')
          : t('AWAY_REASONS.API.ADD_ERROR'))
    );
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="
        isEdit
          ? $t('AWAY_REASONS.FORM.EDIT_TITLE')
          : $t('AWAY_REASONS.FORM.ADD_TITLE')
      "
    />
    <form class="flex flex-wrap mx-0" @submit.prevent="onSubmit">
      <woot-input
        v-model="name"
        :class="{ error: !!nameError }"
        class="w-full"
        :styles="{
          borderRadius: '0.75rem',
          padding: '0.375rem 0.75rem',
          fontSize: '0.875rem',
        }"
        :label="$t('AWAY_REASONS.FORM.NAME.LABEL')"
        :placeholder="$t('AWAY_REASONS.FORM.NAME.PLACEHOLDER')"
        :error="nameError"
        @blur="touched = true"
      />
      <div class="flex items-center justify-end w-full gap-2 mt-8">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('AWAY_REASONS.FORM.CANCEL')"
          @click.prevent="emit('close')"
        />
        <NextButton
          type="submit"
          :label="$t('AWAY_REASONS.FORM.SAVE')"
          :disabled="!name.trim() || isSaving"
          :is-loading="isSaving"
        />
      </div>
    </form>
  </div>
</template>

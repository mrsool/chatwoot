<script setup>
import { ref, watch, nextTick } from 'vue';
import Button from 'next/button/Button.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  secondsLeft: { type: Number, default: 60 },
});

const emit = defineEmits(['confirm']);

const confirmButton = ref(null);
watch(
  () => props.show,
  async visible => {
    if (!visible) return;
    await nextTick();
    confirmButton.value?.$el?.focus();
  },
  { immediate: true }
);
</script>

<template>
  <div
    v-if="show"
    data-testid="still-there"
    role="alertdialog"
    aria-modal="true"
    aria-labelledby="still-there-title"
    class="fixed inset-0 z-[10000] flex items-center justify-center bg-n-alpha-black1 backdrop-blur-[2px]"
  >
    <div
      class="flex flex-col gap-4 w-full max-w-sm p-6 mx-4 rounded-xl shadow-xl bg-n-alpha-3 outline outline-1 outline-n-container backdrop-blur-[100px]"
    >
      <h3 id="still-there-title" class="m-0 text-heading-2 text-n-slate-12">
        {{ $t('IDLE_AWAY.PROMPT.TITLE') }}
      </h3>
      <p class="m-0 text-body-para text-n-slate-11">
        {{ $t('IDLE_AWAY.PROMPT.COUNTDOWN', { seconds: secondsLeft }) }}
      </p>
      <div class="flex justify-end">
        <Button
          ref="confirmButton"
          data-testid="still-there-confirm"
          :label="$t('IDLE_AWAY.PROMPT.CONFIRM')"
          @click="emit('confirm')"
        />
      </div>
    </div>
  </div>
</template>

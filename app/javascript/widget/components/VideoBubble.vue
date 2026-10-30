<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import MediaPreview from 'widget/components/MediaPreview.vue';

defineProps({
  url: { type: String, default: '' },
  readableTime: { type: String, default: '' },
});

const emit = defineEmits(['error']);

const { t } = useI18n();

const isPreviewOpen = ref(false);

const onVideoError = () => {
  emit('error');
};
</script>

<template>
  <div class="relative block max-w-full">
    <video
      class="w-full max-w-[250px] h-auto"
      :src="url"
      controls
      @error="onVideoError"
    />
    <!-- The video owns taps on itself for play/pause, so expanding needs a
    control of its own rather than a tap on the frame. -->
    <button
      type="button"
      :aria-label="t('COMPONENTS.MEDIA_PREVIEW.EXPAND')"
      :title="t('COMPONENTS.MEDIA_PREVIEW.EXPAND')"
      class="absolute flex items-center justify-center text-white rounded-full top-2 end-2 size-8 bg-black/50"
      @click="isPreviewOpen = true"
    >
      <span class="i-lucide-expand size-4" aria-hidden="true" />
    </button>
    <span
      class="absolute text-xs text-white dark:text-white right-3 bottom-1 whitespace-nowrap"
    >
      {{ readableTime }}
    </span>
  </div>
  <MediaPreview
    v-if="isPreviewOpen"
    :url="url"
    file-type="video"
    @close="isPreviewOpen = false"
  />
</template>

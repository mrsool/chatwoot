<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import MediaPreview from 'widget/components/MediaPreview.vue';
import { isMediaPreviewEnabled } from 'widget/helpers/urlParamsHelper';

defineProps({
  url: { type: String, default: '' },
  thumb: { type: String, default: '' },
  readableTime: { type: String, default: '' },
});

const emit = defineEmits(['error']);

const { t } = useI18n();

const isPreviewOpen = ref(false);
const previewEnabled = isMediaPreviewEnabled(window.location.search);

// Stays an anchor either way: without the param the browser follows it to a
// new tab, exactly as before the preview existed.
const onClick = event => {
  if (!previewEnabled) return;

  event.preventDefault();
  isPreviewOpen.value = true;
};
</script>

<template>
  <a
    :href="url"
    :target="previewEnabled ? null : '_blank'"
    rel="noreferrer noopener nofollow"
    class="image"
    :class="{ 'w-fit': previewEnabled }"
    @click="onClick"
  >
    <div class="wrap">
      <img
        :src="thumb"
        :alt="t('COMPONENTS.MEDIA_PREVIEW.IMAGE_ALT')"
        @error="emit('error')"
      />
      <span class="time">{{ readableTime }}</span>
    </div>
  </a>
  <MediaPreview
    v-if="isPreviewOpen"
    :url="url"
    file-type="image"
    @close="isPreviewOpen = false"
  />
</template>

<style lang="scss" scoped>
.image {
  display: block;

  .wrap {
    position: relative;
    display: flex;
    max-width: 100%;

    &::before {
      background-image: linear-gradient(-180deg, transparent 3%, #1f2d3d 130%);
      bottom: 0;
      content: '';
      height: 20%;
      left: 0;
      opacity: 0.8;
      position: absolute;
      width: 100%;
    }
  }

  img {
    width: 100%;
    max-width: 250px;
  }

  .time {
    @apply text-xs bottom-1 text-white ltr:right-3 rtl:left-3 whitespace-nowrap absolute;
  }
}
</style>

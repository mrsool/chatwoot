<script setup>
import { computed, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  url: { type: String, required: true },
  fileType: { type: String, required: true },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const fileName = computed(() =>
  decodeURI(props.url.substring(props.url.lastIndexOf('/') + 1))
);

const onKeydown = e => {
  if (e.key === 'Escape') emit('close');
};

onMounted(() => document.addEventListener('keydown', onKeydown));
onBeforeUnmount(() => document.removeEventListener('keydown', onKeydown));
</script>

<template>
  <Teleport to="body">
    <div
      role="dialog"
      aria-modal="true"
      class="fixed inset-0 z-50 flex flex-col bg-black/90"
      @click="emit('close')"
    >
      <div class="flex items-center justify-end gap-2 p-3" @click.stop>
        <!-- data_url is a same-origin ActiveStorage route, so the browser
        honours `download`, and a WebView gets a real url its download
        listener can hand to the OS -- a blob would give it neither. -->
        <a
          :href="url"
          :download="fileName"
          :aria-label="t('COMPONENTS.MEDIA_PREVIEW.DOWNLOAD')"
          :title="t('COMPONENTS.MEDIA_PREVIEW.DOWNLOAD')"
          class="flex items-center justify-center text-white rounded-full size-10 bg-white/10"
        >
          <span class="i-lucide-download size-5" aria-hidden="true" />
        </a>
        <button
          type="button"
          :aria-label="t('COMPONENTS.MEDIA_PREVIEW.CLOSE')"
          :title="t('COMPONENTS.MEDIA_PREVIEW.CLOSE')"
          class="flex items-center justify-center text-white rounded-full size-10 bg-white/10"
          @click="emit('close')"
        >
          <span class="i-lucide-x size-5" aria-hidden="true" />
        </button>
      </div>
      <div class="flex items-center justify-center flex-1 min-h-0 p-3">
        <img
          v-if="fileType === 'image'"
          :src="url"
          :alt="t('COMPONENTS.MEDIA_PREVIEW.IMAGE_ALT')"
          class="object-contain max-w-full max-h-full"
          @click.stop
        />
        <video
          v-else
          :src="url"
          controls
          autoplay
          class="object-contain max-w-full max-h-full"
          @click.stop
        />
      </div>
    </div>
  </Teleport>
</template>

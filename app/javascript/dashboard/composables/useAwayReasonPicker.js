import { ref } from 'vue';

// Shared so the status menu (inside a dropdown that unmounts on close) can
// request the picker while a always-mounted parent actually renders it.
const isAwayReasonPickerOpen = ref(false);

export const useAwayReasonPicker = () => ({
  isAwayReasonPickerOpen,
  openAwayReasonPicker: () => {
    isAwayReasonPickerOpen.value = true;
  },
  closeAwayReasonPicker: () => {
    isAwayReasonPickerOpen.value = false;
  },
});

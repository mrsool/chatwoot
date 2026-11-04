import { mount } from '@vue/test-utils';
import FileBubble from '../FileBubble.vue';
import ImageBubble from '../ImageBubble.vue';
import MediaPreview from '../MediaPreview.vue';
import VideoBubble from '../VideoBubble.vue';

// The preview replaces a new tab, which only a host that owns navigation can
// afford to lose. Every assertion here is about which of the two a given
// search string selects -- see isMediaPreviewEnabled.
const withSearch = search => {
  vi.spyOn(window, 'location', 'get').mockReturnValue({
    ...window.location,
    search,
  });
};

const ENABLED = '?website_token=3&media_preview=1';
const DISABLED = '?website_token=3';

describe('media preview gating', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('ImageBubble', () => {
    const mountBubble = () =>
      mount(ImageBubble, {
        props: { url: '/rails/active_storage/car.png', thumb: '/thumb.png' },
      });

    it('opens the preview in place when the host asked for it', async () => {
      withSearch(ENABLED);
      const wrapper = mountBubble();

      expect(wrapper.get('a').attributes('target')).toBeUndefined();

      await wrapper.get('a').trigger('click');

      expect(wrapper.findComponent(MediaPreview).exists()).toBe(true);
    });

    it('opens a new tab, and no preview, by default', async () => {
      withSearch(DISABLED);
      const wrapper = mountBubble();

      expect(wrapper.get('a').attributes('target')).toBe('_blank');

      await wrapper.get('a').trigger('click');

      expect(wrapper.findComponent(MediaPreview).exists()).toBe(false);
    });
  });

  describe('VideoBubble', () => {
    const mountBubble = () =>
      mount(VideoBubble, {
        props: { url: '/rails/active_storage/clip.mp4' },
      });

    it('offers an expand control when the host asked for it', () => {
      withSearch(ENABLED);

      expect(mountBubble().find('button').exists()).toBe(true);
    });

    // The video owns taps on itself, so without the preview there is nothing
    // the control could do.
    it('offers none by default', () => {
      withSearch(DISABLED);

      expect(mountBubble().find('button').exists()).toBe(false);
    });
  });

  describe('FileBubble', () => {
    const mountBubble = () =>
      mount(FileBubble, {
        props: { url: '/rails/active_storage/invoice.pdf' },
        global: { stubs: { FluentIcon: true } },
      });

    it('downloads in place when the host asked for it', () => {
      withSearch(ENABLED);
      const link = mountBubble().get('a.download');

      expect(link.attributes('download')).toBe('invoice.pdf');
      expect(link.attributes('target')).toBeUndefined();
    });

    it('opens a new tab by default', () => {
      withSearch(DISABLED);
      const link = mountBubble().get('a.download');

      expect(link.attributes('download')).toBeUndefined();
      expect(link.attributes('target')).toBe('_blank');
    });
  });
});

import { mount } from '@vue/test-utils';
import StillThereModal from '../StillThereModal.vue';

const mountModal = props =>
  mount(StillThereModal, {
    props,
    global: { mocks: { $t: (key, p) => `${key}:${p?.seconds ?? ''}` } },
  });

describe('StillThereModal', () => {
  it('renders nothing when closed', () => {
    const wrapper = mountModal({ show: false, secondsLeft: 60 });
    expect(wrapper.find('[data-testid="still-there"]').exists()).toBe(false);
  });

  it('shows the seconds left', () => {
    const wrapper = mountModal({ show: true, secondsLeft: 42 });
    expect(wrapper.text()).toContain('IDLE_AWAY.PROMPT.COUNTDOWN:42');
  });

  it('emits confirm when the button is clicked', async () => {
    const wrapper = mountModal({ show: true, secondsLeft: 42 });
    await wrapper.find('[data-testid="still-there-confirm"]').trigger('click');
    expect(wrapper.emitted('confirm')).toHaveLength(1);
  });

  it('labels the dialog and focuses the confirm button on open', async () => {
    const wrapper = mount(StillThereModal, {
      props: { show: false, secondsLeft: 60 },
      attachTo: document.body,
      global: { mocks: { $t: key => key } },
    });
    await wrapper.setProps({ show: true });
    await wrapper.vm.$nextTick();
    const dialog = wrapper.find('[role="alertdialog"]');
    const title = wrapper.find(`#${dialog.attributes('aria-labelledby')}`);
    expect(title.text()).toBe('IDLE_AWAY.PROMPT.TITLE');
    expect(document.activeElement).toBe(
      wrapper.find('[data-testid="still-there-confirm"]').element
    );
    wrapper.unmount();
  });
});

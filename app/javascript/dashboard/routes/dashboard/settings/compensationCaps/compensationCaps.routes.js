import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

const meta = {
  featureFlag: FEATURE_FLAGS.FAZAA_COMPENSATION_CAPS,
  permissions: ['administrator'],
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/compensation-caps'),
      component: SettingsWrapper,
      props: {},
      children: [
        {
          path: '',
          name: 'compensation_caps_wrapper',
          meta,
          redirect: to => {
            return { name: 'compensation_caps_index', params: to.params };
          },
        },
        {
          path: 'index',
          name: 'compensation_caps_index',
          meta,
          component: Index,
        },
      ],
    },
  ],
};

import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

const meta = {
  featureFlag: FEATURE_FLAGS.FAZAA_WFM,
  permissions: ['administrator'],
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/away-reasons'),
      component: SettingsWrapper,
      props: {},
      children: [
        {
          path: '',
          name: 'away_reasons_wrapper',
          meta,
          redirect: to => {
            return { name: 'away_reasons_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'away_reasons_list',
          meta,
          component: Index,
        },
      ],
    },
  ],
};

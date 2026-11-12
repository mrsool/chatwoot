import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import AwayReasonsAPI from '../../api/awayReasons';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
  },
};

export const getters = {
  getAwayReasons(_state) {
    return _state.records;
  },
  getActive(_state) {
    return _state.records
      .filter(record => record.active !== false)
      .sort((a, b) => a.position - b.position);
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function get({ commit }, params = {}) {
    commit(types.SET_AWAY_REASONS_UI_FLAG, { isFetching: true });
    try {
      const response = await AwayReasonsAPI.get(params);
      commit(types.SET_AWAY_REASONS, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_AWAY_REASONS_UI_FLAG, { isFetching: false });
    }
  },

  create: async function create({ commit }, reasonObj) {
    commit(types.SET_AWAY_REASONS_UI_FLAG, { isCreating: true });
    try {
      const response = await AwayReasonsAPI.create(reasonObj);
      commit(types.ADD_AWAY_REASON, response.data.payload);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_AWAY_REASONS_UI_FLAG, { isCreating: false });
    }
  },

  update: async function update({ commit }, { id, ...reasonObj }) {
    commit(types.SET_AWAY_REASONS_UI_FLAG, { isUpdating: true });
    try {
      const response = await AwayReasonsAPI.update(id, reasonObj);
      commit(types.EDIT_AWAY_REASON, response.data.payload);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_AWAY_REASONS_UI_FLAG, { isUpdating: false });
    }
  },

  // Soft deactivate; reactivate with update({ id, active: true })
  deactivate: async function deactivate({ commit }, id) {
    commit(types.SET_AWAY_REASONS_UI_FLAG, { isUpdating: true });
    try {
      await AwayReasonsAPI.delete(id);
      commit(types.EDIT_AWAY_REASON, { id, active: false });
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_AWAY_REASONS_UI_FLAG, { isUpdating: false });
    }
  },
};

export const mutations = {
  [types.SET_AWAY_REASONS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_AWAY_REASONS]: MutationHelpers.set,
  [types.ADD_AWAY_REASON]: MutationHelpers.create,
  [types.EDIT_AWAY_REASON]: MutationHelpers.updateAttributes,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};

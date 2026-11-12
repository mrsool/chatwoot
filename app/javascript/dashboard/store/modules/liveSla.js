import types from '../mutation-types';
import LiveSlaAPI from '../../api/liveSla';

export const state = {
  summary: null,
  rows: [],
  serverTime: 0,
  // Local clock (ms) at the moment the payload arrived; used with serverTime
  // so a wrong local clock never distorts the countdown.
  fetchedAt: 0,
  staleSince: null,
};

export const getters = {
  getSummary: _state => _state.summary,
  getRows: _state => _state.rows,
  getServerTime: _state => _state.serverTime,
  getFetchedAt: _state => _state.fetchedAt,
  getStaleSince: _state => _state.staleSince,
};

const compact = filters =>
  Object.fromEntries(
    Object.entries(filters).filter(
      ([, value]) => value !== null && value !== undefined && value !== ''
    )
  );

export const actions = {
  fetch: async ({ commit }, filters = {}) => {
    try {
      const { data } = await LiveSlaAPI.get(compact(filters));
      commit(types.SET_LIVE_SLA, { ...data, fetchedAt: Date.now() });
    } catch (error) {
      commit(types.SET_LIVE_SLA_STALE, Date.now());
    }
  },
};

export const mutations = {
  [types.SET_LIVE_SLA](_state, data) {
    _state.summary = data.summary;
    _state.rows = data.rows;
    _state.serverTime = data.server_time;
    _state.fetchedAt = data.fetchedAt;
    _state.staleSince = null;
  },
  [types.SET_LIVE_SLA_STALE](_state, at) {
    // Keep the original moment the data went stale across repeated failures
    if (!_state.staleSince) _state.staleSince = at;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};

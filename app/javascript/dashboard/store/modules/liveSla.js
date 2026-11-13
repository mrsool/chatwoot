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
  forbidden: false,
};

export const getters = {
  getSummary: _state => _state.summary,
  getRows: _state => _state.rows,
  getServerTime: _state => _state.serverTime,
  getFetchedAt: _state => _state.fetchedAt,
  getStaleSince: _state => _state.staleSince,
  getForbidden: _state => _state.forbidden,
};

const compact = filters =>
  Object.fromEntries(
    Object.entries(filters).filter(
      ([, value]) => value !== null && value !== undefined && value !== ''
    )
  );

// Only the most recent request may update the store, so a slow older
// response (or one made with old filters) never overwrites newer data.
let latest = 0;

export const actions = {
  // The page calls this on mount so a 403 from an earlier visit (e.g. before
  // the user's role changed) does not keep the board halted.
  resetForbidden: ({ commit }) => commit(types.RESET_LIVE_SLA_FORBIDDEN),
  fetch: async ({ commit }, filters = {}) => {
    latest += 1;
    const id = latest;
    const fetchedAt = Date.now();
    try {
      const { data } = await LiveSlaAPI.get(compact(filters));
      if (id !== latest) return;
      commit(types.SET_LIVE_SLA, { ...data, fetchedAt });
    } catch (error) {
      if (id !== latest) return;
      if (error?.response?.status === 403) {
        commit(types.SET_LIVE_SLA_FORBIDDEN);
      } else {
        commit(types.SET_LIVE_SLA_STALE, Date.now());
      }
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
    _state.forbidden = false;
  },
  [types.SET_LIVE_SLA_FORBIDDEN](_state) {
    _state.forbidden = true;
  },
  [types.RESET_LIVE_SLA_FORBIDDEN](_state) {
    _state.forbidden = false;
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

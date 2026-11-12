import axios from 'axios';
import { actions, mutations, getters } from '../../liveSla';
import types from '../../../mutation-types';

global.axios = axios;
vi.mock('axios');

const payload = {
  summary: { breached: 1, at_risk: 0, hit_rate: 0.87, window_hours: 24 },
  rows: [{ conversation_id: 1, display_id: 11, worst_state: 'breached' }],
  server_time: 1000,
};

describe('liveSla store', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-12T10:00:00Z'));
  });
  afterEach(() => vi.useRealTimers());

  describe('#fetch', () => {
    it('passes the non-empty filters as query params and commits the payload', async () => {
      axios.get.mockResolvedValue({ data: payload });
      const commit = vi.fn();
      await actions.fetch(
        { commit },
        { inbox_id: 3, team_id: null, cr_code: '', country: 'SA' }
      );
      expect(axios.get).toHaveBeenCalledTimes(1);
      expect(axios.get.mock.calls[0][0]).toMatch(/reports\/live_sla$/);
      expect(axios.get.mock.calls[0][1]).toEqual({
        params: { inbox_id: 3, country: 'SA' },
      });
      expect(commit).toHaveBeenCalledWith(types.SET_LIVE_SLA, {
        ...payload,
        fetchedAt: Date.now(),
      });
    });

    it('lets the latest request win when responses arrive out of order', async () => {
      let resolveOld;
      axios.get
        .mockReturnValueOnce(
          new Promise(r => {
            resolveOld = r;
          })
        )
        .mockResolvedValueOnce({ data: { ...payload, server_time: 2000 } });
      const commit = vi.fn();
      const older = actions.fetch({ commit }, { inbox_id: 1 });
      await actions.fetch({ commit }, { inbox_id: 2 });
      resolveOld({ data: { ...payload, server_time: 1 } });
      await older;
      expect(commit).toHaveBeenCalledTimes(1);
      expect(commit.mock.calls[0][1].server_time).toBe(2000);
    });

    it('sets forbidden on 403 without marking stale', async () => {
      axios.get.mockRejectedValue({ response: { status: 403 } });
      const commit = vi.fn();
      await actions.fetch({ commit }, {});
      expect(commit).toHaveBeenCalledWith(types.SET_LIVE_SLA_FORBIDDEN);
    });

    it('keeps previous rows and sets staleSince when the request fails', async () => {
      axios.get.mockRejectedValue(new Error('boom'));
      const state = { rows: payload.rows, staleSince: null, uiFlags: {} };
      const commit = (type, value) => mutations[type](state, value);
      await actions.fetch({ commit }, {});
      expect(state.rows).toEqual(payload.rows);
      expect(state.staleSince).toBe(Date.now());
    });
  });

  describe('mutations and getters', () => {
    it('SET_LIVE_SLA replaces the data and clears staleSince', () => {
      const state = { staleSince: 5, rows: [], summary: null };
      mutations[types.SET_LIVE_SLA](state, { ...payload, fetchedAt: 42 });
      expect(state).toMatchObject({
        staleSince: null,
        rows: payload.rows,
        summary: payload.summary,
        serverTime: 1000,
        fetchedAt: 42,
      });
    });

    it('exposes the state through getters', () => {
      const state = { rows: [1], summary: { a: 1 }, staleSince: 9 };
      expect(getters.getRows(state)).toEqual([1]);
      expect(getters.getSummary(state)).toEqual({ a: 1 });
      expect(getters.getStaleSince(state)).toBe(9);
    });
  });
});

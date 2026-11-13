import axios from 'axios';
import { actions } from '../../awayReasons';
import types from '../../../mutation-types';
import reasons from './fixtures';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('#actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('#get', () => {
    it('commits the records on success', async () => {
      axios.get.mockResolvedValue({ data: { payload: reasons } });
      await actions.get({ commit });
      expect(commit.mock.calls).toEqual([
        [types.SET_AWAY_REASONS_UI_FLAG, { isFetching: true }],
        [types.SET_AWAY_REASONS, reasons],
        [types.SET_AWAY_REASONS_UI_FLAG, { isFetching: false }],
      ]);
    });

    it('requests inactive reasons when all is set', async () => {
      axios.get.mockResolvedValue({ data: { payload: reasons } });
      await actions.get({ commit }, { all: true });
      expect(axios.get.mock.calls[0][0]).toMatch(/away_reasons\?all=true$/);
    });

    it('swallows errors and resets the flag', async () => {
      axios.get.mockRejectedValue({ message: 'nope' });
      await actions.get({ commit });
      expect(commit.mock.calls).toEqual([
        [types.SET_AWAY_REASONS_UI_FLAG, { isFetching: true }],
        [types.SET_AWAY_REASONS_UI_FLAG, { isFetching: false }],
      ]);
    });
  });

  describe('#create', () => {
    it('adds the created record, nesting params under away_reason', async () => {
      axios.post.mockResolvedValue({ data: { payload: reasons[0] } });
      await actions.create({ commit }, { name: 'Lunch', position: 2 });
      expect(axios.post.mock.calls[0][1]).toEqual({
        away_reason: { name: 'Lunch', position: 2 },
      });
      expect(commit.mock.calls).toEqual([
        [types.SET_AWAY_REASONS_UI_FLAG, { isCreating: true }],
        [types.ADD_AWAY_REASON, reasons[0]],
        [types.SET_AWAY_REASONS_UI_FLAG, { isCreating: false }],
      ]);
    });

    it('throws the server message on failure', async () => {
      axios.post.mockRejectedValue({
        response: { data: { message: 'Name has already been taken' } },
      });
      await expect(actions.create({ commit }, { name: 'x' })).rejects.toThrow(
        'Name has already been taken'
      );
      expect(commit).toHaveBeenLastCalledWith(types.SET_AWAY_REASONS_UI_FLAG, {
        isCreating: false,
      });
    });
  });

  describe('#update', () => {
    it('edits the record', async () => {
      const updated = { ...reasons[0], name: 'Break' };
      axios.patch.mockResolvedValue({ data: { payload: updated } });
      await actions.update({ commit }, { id: 1, name: 'Break' });
      expect(axios.patch.mock.calls[0][1]).toEqual({
        away_reason: { name: 'Break' },
      });
      expect(commit.mock.calls).toEqual([
        [types.SET_AWAY_REASONS_UI_FLAG, { isUpdating: true }],
        [types.EDIT_AWAY_REASON, updated],
        [types.SET_AWAY_REASONS_UI_FLAG, { isUpdating: false }],
      ]);
    });
  });

  describe('#deactivate', () => {
    it('marks the record inactive after DELETE', async () => {
      axios.delete.mockResolvedValue({});
      await actions.deactivate({ commit }, 1);
      expect(commit.mock.calls).toEqual([
        [types.SET_AWAY_REASONS_UI_FLAG, { isUpdating: true }],
        [types.EDIT_AWAY_REASON, { id: 1, active: false }],
        [types.SET_AWAY_REASONS_UI_FLAG, { isUpdating: false }],
      ]);
    });
  });
});

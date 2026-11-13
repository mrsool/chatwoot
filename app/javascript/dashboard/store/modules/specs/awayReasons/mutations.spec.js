import types from '../../../mutation-types';
import { mutations } from '../../awayReasons';
import reasons from './fixtures';

describe('#mutations', () => {
  it('SET_AWAY_REASONS_UI_FLAG merges ui flags', () => {
    const state = { uiFlags: { isCreating: false } };
    mutations[types.SET_AWAY_REASONS_UI_FLAG](state, { isFetching: true });
    expect(state.uiFlags).toEqual({ isCreating: false, isFetching: true });
  });

  it('SET_AWAY_REASONS replaces records', () => {
    const state = { records: [] };
    mutations[types.SET_AWAY_REASONS](state, reasons);
    expect(state.records).toEqual(reasons);
  });

  it('ADD_AWAY_REASON appends a record', () => {
    const state = { records: [reasons[0]] };
    mutations[types.ADD_AWAY_REASON](state, reasons[1]);
    expect(state.records).toEqual([reasons[0], reasons[1]]);
  });

  it('EDIT_AWAY_REASON merges attributes into the matching record', () => {
    const state = { records: [reasons[0], reasons[1]] };
    mutations[types.EDIT_AWAY_REASON](state, { id: 1, active: false });
    expect(state.records[0]).toEqual({ ...reasons[0], active: false });
    expect(state.records[1]).toEqual(reasons[1]);
  });
});

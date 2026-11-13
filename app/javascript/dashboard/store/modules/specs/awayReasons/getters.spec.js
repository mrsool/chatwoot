import { getters } from '../../awayReasons';
import reasons from './fixtures';

describe('#getters', () => {
  it('getAwayReasons returns every record', () => {
    expect(getters.getAwayReasons({ records: reasons })).toEqual(reasons);
  });

  it('getActive hides inactive reasons and sorts by position', () => {
    const result = getters.getActive({ records: reasons });
    expect(result.map(r => r.id)).toEqual([2, 1]);
  });

  it('getUIFlags returns the ui flags', () => {
    const uiFlags = { isFetching: true };
    expect(getters.getUIFlags({ uiFlags })).toEqual(uiFlags);
  });
});

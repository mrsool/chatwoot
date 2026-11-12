/* global axios */
import ApiClient from './ApiClient';

class AwayReasonsAPI extends ApiClient {
  constructor() {
    super('away_reasons', { accountScoped: true });
  }

  // `all` is admin-only and includes deactivated reasons
  get({ all = false } = {}) {
    return axios.get(all ? `${this.url}?all=true` : this.url);
  }

  create(data) {
    return super.create({ away_reason: data });
  }

  update(id, data) {
    return super.update(id, { away_reason: data });
  }
}

export default new AwayReasonsAPI();

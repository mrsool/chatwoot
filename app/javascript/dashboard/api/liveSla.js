/* global axios */
import ApiClient from './ApiClient';

class LiveSlaAPI extends ApiClient {
  constructor() {
    super('reports/live_sla', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new LiveSlaAPI();

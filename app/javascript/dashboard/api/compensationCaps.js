/* global axios */
import ApiClient from './ApiClient';

class CompensationCapsAPI extends ApiClient {
  constructor() {
    super('compensation_caps', { accountScoped: true });
  }

  // Singleton resource per account: no :id in the path
  get() {
    return axios.get(this.url);
  }

  update(payload) {
    return axios.patch(this.url, { compensation_caps: payload });
  }
}

export default new CompensationCapsAPI();

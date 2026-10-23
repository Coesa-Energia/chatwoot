/* global axios */
import ApiClient from './ApiClient';

class InboxMembers extends ApiClient {
  constructor() {
    super('inbox_members', { accountScoped: true });
  }

  // `seeAllIds` (optional): the agents that may see every conversation of the inbox; the others only see
  // the conversations assigned to them or where they take part.
  // `rotationIds` (optional): the agents that take part in the automatic assignment of the inbox; the others
  // keep their access but are never picked.
  update({ inboxId, agentList, seeAllIds, rotationIds }) {
    const payload = { inbox_id: inboxId, user_ids: agentList };
    if (seeAllIds) payload.see_all_user_ids = seeAllIds;
    if (rotationIds) payload.rotation_user_ids = rotationIds;
    return axios.patch(this.url, payload);
  }
}

export default new InboxMembers();

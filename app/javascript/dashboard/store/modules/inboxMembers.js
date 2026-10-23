import InboxMembersAPI from '../../api/inboxMembers';

export const actions = {
  get(_, { inboxId }) {
    return InboxMembersAPI.show(inboxId);
  },
  create(_, { inboxId, agentList, seeAllIds, rotationIds }) {
    return InboxMembersAPI.update({
      inboxId,
      agentList,
      seeAllIds,
      rotationIds,
    });
  },
};

export default {
  namespaced: true,
  actions,
};

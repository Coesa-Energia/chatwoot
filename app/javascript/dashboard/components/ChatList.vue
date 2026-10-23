<script setup>
import { ref, unref, provide, computed, watch, onMounted } from 'vue';
import { useIntervalFn } from '@vueuse/core';
import { useStore } from 'vuex';
import { useRouter, useRoute } from 'vue-router';
import {
  useMapGetter,
  useFunctionGetter,
} from 'dashboard/composables/store.js';

import ChatListHeader from './ChatListHeader.vue';
import ConversationList from './ConversationList.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ConversationFilter from 'next/filter/ConversationFilter.vue';
import SaveCustomView from 'next/filter/SaveCustomView.vue';
import ChatTypeTabs from './widgets/ChatTypeTabs.vue';
import DeleteCustomViews from 'dashboard/routes/dashboard/customviews/DeleteCustomViews.vue';
import ConversationBulkActions from './widgets/conversation/conversationBulkActions/Index.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';
import ConversationResolveAttributesModal from 'dashboard/components-next/ConversationWorkflow/ConversationResolveAttributesModal.vue';

import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import { useBulkActions } from 'dashboard/composables/chatlist/useBulkActions';
import { useFilter } from 'shared/composables/useFilter';
import { useTrack } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import {
  useCamelCase,
  useSnakeCase,
} from 'dashboard/composables/useTransformKeys';
import { useEmitter } from 'dashboard/composables/emitter';
import { useConversationRequiredAttributes } from 'dashboard/composables/useConversationRequiredAttributes';
import ConversationApi from 'dashboard/api/inbox/conversation';

import { emitter } from 'shared/helpers/mitt';

import wootConstants from 'dashboard/constants/globals';
import advancedFilterOptions from './widgets/conversation/advancedFilterItems';
import filterQueryGenerator from '../helper/filterQueryGenerator.js';
import { parseRouteFilters } from 'dashboard/helper/validations';
import {
  isConversationArchived,
  pinnedFirst,
} from 'dashboard/helper/conversationUserState';
import languages from 'dashboard/components/widgets/conversation/advancedFilterItems/languages';
import countries from 'shared/constants/countries';
import { generateValuesForEditCustomViews } from 'dashboard/helper/customViewsHelper';
import { useConversationRoutePath } from 'dashboard/composables/useConversationRoutePath';
import {
  getUserPermissions,
  filterItemsByPermission,
} from 'dashboard/helper/permissionsHelper.js';
import { createFiltersMatcher } from '../store/modules/conversations/helpers/filterHelpers';
import { sortComparator } from '../store/modules/conversations/helpers';
import { CONVERSATION_EVENTS } from '../helper/AnalyticsHelper/events';
import {
  getVoiceCallProvider,
  VOICE_CALL_PROVIDERS,
} from 'dashboard/helper/inbox';
import { ASSIGNEE_TYPE_TAB_PERMISSIONS } from 'dashboard/constants/permissions.js';
import {
  useSellerMode,
  SELLER_MODE_STATUS_FILTERS,
  SELLER_MODE_SORT_OPTIONS,
} from 'dashboard/composables/useSellerMode';

const props = defineProps({
  conversationInbox: { type: [String, Number], default: 0 },
  teamId: { type: [String, Number], default: 0 },
  label: { type: String, default: '' },
  conversationType: { type: String, default: '' },
  foldersId: { type: [String, Number], default: 0 },
  showConversationList: { default: true, type: Boolean },
  isOnExpandedLayout: { default: false, type: Boolean },
});

const emit = defineEmits(['conversationLoad']);
const { uiSettings } = useUISettings();
const { isSellerMode } = useSellerMode();
const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const store = useStore();
const { buildConversationPath, buildConversationListPath } =
  useConversationRoutePath();

const resolveAttributesModalRef = ref(null);

const activeAssigneeTab = ref(wootConstants.ASSIGNEE_TYPE.ME);
const activeStatus = ref(wootConstants.STATUS_TYPE.OPEN);
const activeSortBy = ref(wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC);
// Quick filter chips (can be combined): unread incoming messages, customer waiting for a reply,
// and the agent's archived conversations.
const unreadOnly = ref(false);
const awaitingReplyOnly = ref(false);
const archivedOnly = ref(false);
// Ids of what the agent archived (they stay out of the main list even when a websocket event for one arrives)
// and how many of those have unread messages (the number on the "Archived" row, like the WhatsApp app).
const archivedIds = ref(new Set());
const archivedUnreadCount = ref(0);
const isArchived = chat =>
  isConversationArchived(chat) || archivedIds.value.has(chat.id);
const showAdvancedFilters = ref(false);
// chatsOnView is to store the chats that are currently visible on the screen,
// which mirrors the conversationList.
const chatsOnView = ref([]);
const foldersQuery = useMapGetter('getAppliedConversationFiltersQuery');
const showAddFoldersModal = ref(false);
const showDeleteFoldersModal = ref(false);
const appliedFilter = ref([]);
const advancedFilterTypes = ref(
  advancedFilterOptions.map(filter => ({
    ...filter,
    attributeName: t(`FILTER.ATTRIBUTES.${filter.attributeI18nKey}`),
  }))
);

const currentUser = useMapGetter('getCurrentUser');
const chatLists = useMapGetter('getFilteredConversations');
const mineChatsList = useMapGetter('getMineChats');
const allChatList = useMapGetter('getAllStatusChats');
const unAssignedChatsList = useMapGetter('getUnAssignedChats');
const participatingChatsList = useMapGetter('getParticipatingChats');
const chatListLoading = useMapGetter('getChatListLoadingStatus');
const activeInbox = useMapGetter('getSelectedInbox');
const conversationStats = useMapGetter('conversationStats/getStats');
const appliedFilters = useMapGetter('getAppliedConversationFiltersV2');
const appliedContactFilter = useMapGetter('getAppliedContactFilter');
const folders = useMapGetter('customViews/getConversationCustomViews');
const agentList = useMapGetter('agents/getAgents');
const teamsList = useMapGetter('teams/getTeams');
const inboxesList = useMapGetter('inboxes/getInboxes');
const campaigns = useMapGetter('campaigns/getAllCampaigns');
const labels = useMapGetter('labels/getLabels');
const currentAccountId = useMapGetter('getCurrentAccountId');
// We can't useFunctionGetter here since it needs to be called on setup?
const getTeamFn = useMapGetter('teams/getTeam');
const getConversationById = useMapGetter('getConversationById');
const selectedChat = useMapGetter('getSelectedChat');

const {
  selectedConversations,
  selectedInboxes,
  selectConversation,
  deSelectConversation,
  selectAllConversations,
  resetBulkActions,
  isConversationSelected,
  onAssignAgent,
  onAssignLabels,
  onRemoveLabels,
} = useBulkActions();

const {
  initializeStatusAndAssigneeFilterToModal,
  initializeInboxTeamAndLabelFilterToModal,
} = useFilter({
  filteri18nKey: 'FILTER',
  attributeModel: 'conversation_attribute',
});

const { checkMissingAttributes } = useConversationRequiredAttributes();

// computed

const hasAppliedFilters = computed(() => {
  return appliedFilters.value.length !== 0;
});

const activeFolder = computed(() => {
  if (props.foldersId) {
    const activeView = folders.value.filter(
      view => view.id === Number(props.foldersId)
    );
    const [firstValue] = activeView;
    return firstValue;
  }
  return undefined;
});

const getContact = useMapGetter('contacts/getContact');
const folderContactId = useMapGetter('customViews/getActiveFolderContactId');

const activeFolderName = computed(() => {
  return activeFolder.value?.name;
});

const hasActiveFolders = computed(() => {
  return Boolean(activeFolder.value && props.foldersId !== 0);
});

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return hasAppliedFilters.value || hasActiveFolders.value;
});

const currentUserDetails = computed(() => {
  const { id, name } = currentUser.value;
  return { id, name };
});

const userPermissions = computed(() => {
  return getUserPermissions(currentUser.value, currentAccountId.value);
});

const assigneeTabItems = computed(() => {
  return filterItemsByPermission(
    ASSIGNEE_TYPE_TAB_PERMISSIONS,
    userPermissions.value,
    item => item.permissions
  ).map(({ key, count: countKey }) => ({
    key,
    name: t(`CHAT_LIST.ASSIGNEE_TYPE_TABS.${key}`),
    count: conversationStats.value[countKey] || 0,
  }));
});

const showAssigneeInConversationCard = computed(() => {
  return (
    hasAppliedFiltersOrActiveFolders.value ||
    activeAssigneeTab.value === wootConstants.ASSIGNEE_TYPE.ALL
  );
});

// The archived screen fetches with assignee type "all" (see conversationFilters), so its pages and its end of
// list are tracked under that key, not under the tab that is selected behind it.
const paginationKey = computed(() =>
  archivedOnly.value ? wootConstants.ASSIGNEE_TYPE.ALL : activeAssigneeTab.value
);

const currentPageFilterKey = computed(() => {
  return hasAppliedFiltersOrActiveFolders.value
    ? 'appliedFilters'
    : paginationKey.value;
});

const inbox = useFunctionGetter('inboxes/getInbox', activeInbox);
const currentPage = useFunctionGetter(
  'conversationPage/getCurrentPageFilter',
  paginationKey
);
const currentFiltersPage = useFunctionGetter(
  'conversationPage/getCurrentPageFilter',
  currentPageFilterKey
);
const hasCurrentPageEndReached = useFunctionGetter(
  'conversationPage/getHasEndReached',
  currentPageFilterKey
);

const conversationCustomAttributes = useFunctionGetter(
  'attributes/getAttributesByModel',
  'conversation_attribute'
);

const activeAssigneeTabCount = computed(() => {
  // An agent without access to the "all" tab has no count for it: nothing to compare with then.
  return (
    assigneeTabItems.value.find(item => item.key === paginationKey.value)
      ?.count ?? 0
  );
});

const conversationListPagination = computed(() => {
  const conversationsPerPage = 25;
  const hasChatsOnView =
    chatsOnView.value &&
    Array.isArray(chatsOnView.value) &&
    !chatsOnView.value.length;
  const isNoFiltersOrFoldersAndChatListNotEmpty =
    !hasAppliedFiltersOrActiveFolders.value && hasChatsOnView;
  const isUnderPerPage =
    chatsOnView.value.length < conversationsPerPage &&
    activeAssigneeTabCount.value < conversationsPerPage &&
    activeAssigneeTabCount.value > chatsOnView.value.length;

  if (isNoFiltersOrFoldersAndChatListNotEmpty && isUnderPerPage) {
    return 1;
  }

  return currentPage.value + 1;
});

const conversationFilters = computed(() => {
  return {
    inboxId: props.conversationInbox ? props.conversationInbox : undefined,
    // The archived screen lists everything the agent archived, whoever it is assigned to and whatever its status.
    assigneeType: archivedOnly.value
      ? wootConstants.ASSIGNEE_TYPE.ALL
      : activeAssigneeTab.value,
    status: archivedOnly.value ? 'all' : activeStatus.value,
    sortBy: activeSortBy.value,
    page: conversationListPagination.value,
    labels: props.label ? [props.label] : undefined,
    teamId: props.teamId || undefined,
    conversationType: props.conversationType || undefined,
    unread: unreadOnly.value || undefined,
    awaitingReply: awaitingReplyOnly.value || undefined,
    archived: archivedOnly.value || undefined,
  };
});

const quickFilters = computed(() => [
  {
    key: 'unread',
    icon: 'i-lucide-message-square-dot',
    label: t('CHAT_LIST.UNREAD_ONLY'),
    active: unreadOnly.value,
  },
  {
    key: 'awaitingReply',
    icon: 'i-lucide-hourglass',
    label: t('CHAT_LIST.AWAITING_REPLY_ONLY'),
    active: awaitingReplyOnly.value,
  },
]);

const emptyStateText = computed(() => {
  if (archivedOnly.value) return t('CHAT_LIST.EMPTY_STATE.ARCHIVED');
  if (unreadOnly.value && awaitingReplyOnly.value) {
    return t('CHAT_LIST.EMPTY_STATE.QUICK_FILTERS');
  }
  if (unreadOnly.value) return t('CHAT_LIST.EMPTY_STATE.UNREAD');
  if (awaitingReplyOnly.value) return t('CHAT_LIST.EMPTY_STATE.AWAITING_REPLY');
  return t('CHAT_LIST.LIST.404');
});

const activeTeam = computed(() => {
  if (props.teamId) {
    return getTeamFn.value(props.teamId);
  }
  return {};
});

const voiceInboxId = computed(() =>
  getVoiceCallProvider(inbox.value) === VOICE_CALL_PROVIDERS.TWILIO
    ? inbox.value.id
    : null
);

const pageTitle = computed(() => {
  if (hasAppliedFilters.value) {
    return t('CHAT_LIST.TAB_HEADING');
  }
  if (inbox.value.name) {
    return inbox.value.name;
  }
  if (activeTeam.value.name) {
    return activeTeam.value.name;
  }
  if (props.label) {
    return `#${props.label}`;
  }
  if (props.conversationType === wootConstants.CONVERSATION_TYPE.MENTION) {
    return t('CHAT_LIST.MENTION_HEADING');
  }
  if (
    props.conversationType === wootConstants.CONVERSATION_TYPE.PARTICIPATING
  ) {
    return t('CONVERSATION_PARTICIPANTS.SIDEBAR_MENU_TITLE');
  }
  if (props.conversationType === wootConstants.CONVERSATION_TYPE.UNATTENDED) {
    return t('CHAT_LIST.UNATTENDED_HEADING');
  }
  if (hasActiveFolders.value) {
    return activeFolder.value.name;
  }
  return t('CHAT_LIST.TAB_HEADING');
});

function filterByAssigneeTab(conversations) {
  if (activeAssigneeTab.value === wootConstants.ASSIGNEE_TYPE.ME) {
    return conversations.filter(
      c => c.meta?.assignee?.id === currentUser.value?.id
    );
  }
  if (activeAssigneeTab.value === wootConstants.ASSIGNEE_TYPE.UNASSIGNED) {
    return conversations.filter(c => !c.meta?.assignee);
  }
  return [...conversations];
}

function sortByUnreadStatus(conversations) {
  return [...conversations].sort((a, b) =>
    sortComparator(a, b, wootConstants.SORT_BY_TYPE.UNREAD)
  );
}

const conversationList = computed(() => {
  let localConversationList = [];

  if (!hasAppliedFiltersOrActiveFolders.value) {
    const filters = conversationFilters.value;
    if (
      props.conversationType === wootConstants.CONVERSATION_TYPE.PARTICIPATING
    ) {
      localConversationList = filterByAssigneeTab(
        participatingChatsList.value(filters)
      );
    } else if (activeAssigneeTab.value === 'me' && !archivedOnly.value) {
      localConversationList = [...mineChatsList.value(filters)];
    } else if (
      activeAssigneeTab.value === 'unassigned' &&
      !archivedOnly.value
    ) {
      localConversationList = [...unAssignedChatsList.value(filters)];
    } else {
      localConversationList = [...allChatList.value(filters)];
    }
  } else {
    localConversationList = [...chatLists.value];
  }

  if (!hasAppliedFiltersOrActiveFolders.value) {
    // Archived conversations are hidden (and shown alone by the "Archived" chip) until something new
    // happens in them; pinned ones always come first. The server applies the same rules, this keeps
    // the list right while conversations change without a refetch.
    localConversationList = pinnedFirst(
      localConversationList.filter(
        chat => isArchived(chat) === archivedOnly.value
      )
    );
  }

  if (
    (unreadOnly.value || awaitingReplyOnly.value) &&
    !hasAppliedFiltersOrActiveFolders.value
  ) {
    // The list is fetched with these filters, but a chat stops matching as soon as it is read or
    // answered. Keep the open chat visible so it doesn't vanish from under the agent.
    const openChatId = selectedChat.value?.id;
    localConversationList = localConversationList.filter(chat => {
      if (chat.id === openChatId) return true;
      if (unreadOnly.value && !(chat.unread_count > 0)) return false;
      if (awaitingReplyOnly.value && !chat.waiting_since) return false;
      return true;
    });
  }

  if (activeFolder.value) {
    const { payload } = activeFolder.value.query;
    localConversationList = localConversationList.filter(
      createFiltersMatcher(payload)
    );
  }

  if (
    !hasAppliedFiltersOrActiveFolders.value &&
    activeSortBy.value === wootConstants.SORT_BY_TYPE.UNREAD
  ) {
    localConversationList = sortByUnreadStatus(localConversationList);
  }

  return localConversationList;
});

const showEndOfListMessage = computed(() => {
  return !!(
    conversationList.value.length &&
    hasCurrentPageEndReached.value &&
    !chatListLoading.value
  );
});

const allConversationsSelected = computed(() => {
  return (
    conversationList.value.length === selectedConversations.value.length &&
    conversationList.value.every(el =>
      selectedConversations.value.includes(el.id)
    )
  );
});

const uniqueInboxes = computed(() => {
  return [...new Set(selectedInboxes.value)];
});

// ---------------------- Methods -----------------------
function setFiltersFromUISettings() {
  const { conversations_filter_by: filterBy = {} } = uiSettings.value;
  const { status, order_by: orderBy } = filterBy;
  activeStatus.value = status || wootConstants.STATUS_TYPE.OPEN;
  activeSortBy.value = Object.values(wootConstants.SORT_BY_TYPE).includes(
    orderBy
  )
    ? orderBy
    : wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC;
  // A saved status/sort that seller mode doesn't offer falls back to the default.
  if (!isSellerMode.value) return;
  if (!SELLER_MODE_STATUS_FILTERS.includes(activeStatus.value)) {
    activeStatus.value = wootConstants.STATUS_TYPE.OPEN;
  }
  if (!SELLER_MODE_SORT_OPTIONS.includes(activeSortBy.value)) {
    activeSortBy.value = wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC;
  }
}

function emitConversationLoaded() {
  emit('conversationLoad');
}

function fetchFilteredConversations(payload) {
  payload = useSnakeCase(payload);
  let page = currentFiltersPage.value + 1;
  store
    .dispatch('fetchFilteredConversations', {
      queryData: filterQueryGenerator(payload),
      page,
      sortBy: activeSortBy.value,
    })
    .catch(() => useAlert(t('CHAT_LIST.FETCH_ERROR')))
    // emit even on failure so a deep-linked conversation still loads via
    // fetchConversationIfUnavailable
    .finally(emitConversationLoaded);

  showAdvancedFilters.value = false;
}

function fetchSavedFilteredConversations(payload) {
  payload = useSnakeCase(payload);
  let page = currentFiltersPage.value + 1;
  store
    .dispatch('fetchFilteredConversations', {
      queryData: payload,
      page,
      sortBy: activeSortBy.value,
    })
    .catch(() => useAlert(t('CHAT_LIST.FETCH_ERROR')))
    .finally(emitConversationLoaded);
}

function onApplyFilter(payload) {
  payload = useSnakeCase(payload);
  showAdvancedFilters.value = false;
  store
    .dispatch('applyConversationFilters', { filters: payload })
    .catch(() => useAlert(t('CHAT_LIST.FETCH_ERROR')))
    .finally(emitConversationLoaded);
}

function applyRouteFilters() {
  const { filters: serializedFilters, ...query } = route.query;
  if (!serializedFilters) return false;

  router.replace({ query });
  const filters = parseRouteFilters(serializedFilters);
  if (!filters) return false;

  store.dispatch('setConversationFilters', filters);
  onApplyFilter(filters);
  return true;
}

function closeAdvanceFiltersModal() {
  showAdvancedFilters.value = false;
  appliedFilter.value = [];
}

function onUpdateSavedFilter(payload, folderName) {
  const transformedPayload = useSnakeCase(payload);
  const payloadData = {
    ...unref(activeFolder),
    name: unref(folderName),
    query: filterQueryGenerator(transformedPayload),
  };
  store.dispatch('customViews/update', payloadData);
  closeAdvanceFiltersModal();
}

function onClickOpenAddFoldersModal() {
  showAddFoldersModal.value = true;
}

function onCloseAddFoldersModal() {
  showAddFoldersModal.value = false;
}

function onClickOpenDeleteFoldersModal() {
  showDeleteFoldersModal.value = true;
}

function onCloseDeleteFoldersModal() {
  showDeleteFoldersModal.value = false;
}

function setParamsForEditFolderModal() {
  // Here we are setting the params for edit folder modal to show the existing values.

  // For agent, team, inboxes,and campaigns we get only the id's from the query.
  // So we are mapping the id's to the actual values.

  // For labels we get the name of the label from the query.
  // If we delete the label from the label list then we will not be able to show the label name.

  // For custom attributes we get only attribute key.
  // So we are mapping it to find the input type of the attribute to show in the edit folder modal.
  return {
    agents: agentList.value,
    teams: teamsList.value,
    inboxes: inboxesList.value,
    labels: labels.value,
    campaigns: campaigns.value,
    contacts: [getContact.value(folderContactId.value)],
    languages: languages,
    countries: countries,
    priority: [
      { id: 'low', name: t('CONVERSATION.PRIORITY.OPTIONS.LOW') },
      { id: 'medium', name: t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM') },
      { id: 'high', name: t('CONVERSATION.PRIORITY.OPTIONS.HIGH') },
      { id: 'urgent', name: t('CONVERSATION.PRIORITY.OPTIONS.URGENT') },
    ],
    filterTypes: advancedFilterTypes.value,
    allCustomAttributes: conversationCustomAttributes.value,
  };
}

function initializeExistingFilterToModal() {
  const statusFilter = initializeStatusAndAssigneeFilterToModal(
    activeStatus.value,
    currentUserDetails.value,
    activeAssigneeTab.value
  );
  // TODO: Remove the usage of useCamelCase after migrating useFilter to camelcase
  if (statusFilter) {
    appliedFilter.value = [...appliedFilter.value, useCamelCase(statusFilter)];
  }

  // TODO: Remove the usage of useCamelCase after migrating useFilter to camelcase
  const otherFilters = initializeInboxTeamAndLabelFilterToModal(
    props.conversationInbox,
    inbox.value,
    props.teamId,
    activeTeam.value,
    props.label
  ).map(useCamelCase);

  appliedFilter.value = [...appliedFilter.value, ...otherFilters];
}

function initializeFolderToFilterModal(newActiveFolder) {
  // Here we are setting the params for edit folder modal.
  //  To show the existing values. when we click on edit folder button.

  // Here we get the query from the active folder.
  // And we are mapping the query to the actual values.
  // To show in the edit folder modal by the help of generateValuesForEditCustomViews helper.
  const query = unref(newActiveFolder)?.query?.payload;
  if (!Array.isArray(query)) return;

  const newFilters = query.map(filter => {
    const transformed = useCamelCase(filter);
    const values = Array.isArray(transformed.values)
      ? generateValuesForEditCustomViews(
          useSnakeCase(filter),
          setParamsForEditFolderModal()
        )
      : [];

    return {
      attributeKey: transformed.attributeKey,
      timezone: transformed.timezone,
      attributeModel: transformed.attributeModel,
      customAttributeType: transformed.customAttributeType,
      filterOperator: transformed.filterOperator,
      queryOperator: transformed.queryOperator ?? 'and',
      values,
    };
  });

  appliedFilter.value = [...appliedFilter.value, ...newFilters];
}

function initalizeAppliedFiltersToModal() {
  appliedFilter.value = [...appliedFilters.value];
}

function onToggleAdvanceFiltersModal() {
  if (showAdvancedFilters.value === true) {
    closeAdvanceFiltersModal();
    return;
  }

  if (!hasAppliedFilters.value && !hasActiveFolders.value) {
    initializeExistingFilterToModal();
  }
  if (hasActiveFolders.value) {
    initializeFolderToFilterModal(activeFolder.value);
  }
  if (hasAppliedFilters.value) {
    initalizeAppliedFiltersToModal();
  }

  showAdvancedFilters.value = true;
}

function fetchConversations() {
  store.dispatch('updateChatListFilters', conversationFilters.value);
  store.dispatch('fetchAllConversations').then(emitConversationLoaded);
}

function resetAndFetchData() {
  appliedFilter.value = [];
  resetBulkActions();
  store.dispatch('conversationPage/reset');
  store.dispatch('emptyAllConversations');
  store.dispatch('clearConversationFilters');
  if (hasActiveFolders.value) {
    const payload = activeFolder.value.query;
    fetchSavedFilteredConversations(payload);
  }
  if (props.foldersId) {
    return;
  }
  fetchConversations();
}

// Leaving a contact's history lands on its latest conversation; the expanded list has no open thread.
function resetFilters() {
  const latestConversation =
    appliedContactFilter.value &&
    !props.isOnExpandedLayout &&
    chatLists.value[0];
  if (latestConversation) {
    router.push(buildConversationPath(latestConversation.id));
  }
  resetAndFetchData();
}

function loadMoreConversations() {
  if (hasCurrentPageEndReached.value || chatListLoading.value) {
    return;
  }

  if (!hasAppliedFiltersOrActiveFolders.value) {
    fetchConversations();
  } else if (hasActiveFolders.value) {
    const payload = activeFolder.value.query;
    fetchSavedFilteredConversations(payload);
  } else if (hasAppliedFilters.value) {
    fetchFilteredConversations(appliedFilters.value);
  }
}

function updateAssigneeTab(selectedTab) {
  if (activeAssigneeTab.value !== selectedTab) {
    resetBulkActions();
    emitter.emit('clearSearchInput');
    activeAssigneeTab.value = selectedTab;
    if (!currentPage.value) {
      fetchConversations();
    } else {
      store.dispatch('invalidateConversationListRequests');
      store.dispatch('updateChatListFilters', conversationFilters.value);
    }
  }
}

function onBasicFilterChange(value, type) {
  if (type === 'status') {
    activeStatus.value = value;
  } else {
    activeSortBy.value = value;
  }

  if (type === 'sort' && hasAppliedFiltersOrActiveFolders.value) {
    resetBulkActions();
    store.dispatch('conversationPage/reset');
    store.dispatch('emptyAllConversations');

    if (hasActiveFolders.value) {
      fetchSavedFilteredConversations(activeFolder.value.query);
    } else {
      fetchFilteredConversations(appliedFilters.value);
    }
    return;
  }

  resetAndFetchData();
}

function toggleQuickFilter(key) {
  if (key === 'unread') {
    unreadOnly.value = !unreadOnly.value;
  } else if (key === 'awaitingReply') {
    awaitingReplyOnly.value = !awaitingReplyOnly.value;
  }
  resetAndFetchData();
}

function clearQuickFilters() {
  unreadOnly.value = false;
  awaitingReplyOnly.value = false;
  resetAndFetchData();
}

// Archived conversations: a row above the filters opens a screen with only those (like the WhatsApp app); its
// number is how many archived conversations have unread messages. The back arrow returns to the normal list.
async function fetchArchivedState() {
  try {
    const [ids, unread] = await Promise.all([
      ConversationApi.archivedIds(),
      ConversationApi.meta({
        status: 'all',
        assigneeType: wootConstants.ASSIGNEE_TYPE.ALL,
        archived: true,
        unread: true,
      }),
    ]);
    archivedIds.value = new Set(ids.data?.payload || []);
    archivedUnreadCount.value = unread.data?.meta?.all_count || 0;
  } catch (error) {
    // Only a convenience; the lists themselves still work.
  }
}

// The unread number changes while the agent works, so refresh it now and then.
useIntervalFn(fetchArchivedState, 60000);

function openArchived() {
  unreadOnly.value = false;
  awaitingReplyOnly.value = false;
  archivedOnly.value = true;
  resetAndFetchData();
}

function closeArchived() {
  archivedOnly.value = false;
  resetAndFetchData();
  fetchArchivedState();
}

// Pin / archive for the current agent only. Both run from the conversation context menu.
async function toggleConversationPin(conversationId, pinned) {
  try {
    await store.dispatch('updateConversationUserState', {
      conversationId,
      pinned,
    });
  } catch (error) {
    useAlert(error?.response?.data?.error || t('CHAT_LIST.PIN_ERROR'));
  }
}

async function toggleConversationArchive(conversationId, archived) {
  try {
    await store.dispatch('updateConversationUserState', {
      conversationId,
      archived,
    });
    if (archived) useAlert(t('CHAT_LIST.ARCHIVED_TOAST'));
    const ids = new Set(archivedIds.value);
    if (archived) ids.add(conversationId);
    else ids.delete(conversationId);
    archivedIds.value = ids;
    fetchArchivedState();
  } catch (error) {
    useAlert(t('CHAT_LIST.ARCHIVE_ERROR'));
  }
}

function openLastSavedItemInFolder() {
  const lastItemOfFolder = folders.value[folders.value.length - 1];
  const lastItemId = lastItemOfFolder.id;
  router.push({
    name: 'folder_conversations',
    params: { id: lastItemId },
  });
}

function openLastItemAfterDeleteInFolder() {
  if (folders.value.length > 0) {
    openLastSavedItemInFolder();
  } else {
    router.push({ name: 'home' });
    fetchConversations();
  }
}

function redirectToConversationList() {
  router.push(buildConversationListPath());
}

async function assignPriority(priority, conversationId = null) {
  store.dispatch('setCurrentChatPriority', {
    priority,
    conversationId,
  });
  store.dispatch('assignPriority', { conversationId, priority }).then(() => {
    useTrack(CONVERSATION_EVENTS.CHANGE_PRIORITY, {
      newValue: priority,
      from: 'Context menu',
    });
    useAlert(
      t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SUCCESSFUL', {
        priority,
        conversationId,
      })
    );
  });
}

async function markAsUnread(conversationId) {
  try {
    await store.dispatch('markMessagesUnread', {
      id: conversationId,
    });
    redirectToConversationList();
  } catch (error) {
    // Ignore error
  }
}
async function markAsRead(conversationId) {
  try {
    await store.dispatch('markMessagesRead', {
      id: conversationId,
    });
  } catch (error) {
    // Ignore error
  }
}

async function onAssignTeam(team, conversationId = null) {
  try {
    await store.dispatch('assignTeam', {
      conversationId,
      teamId: team.id,
    });
    useAlert(
      t('CONVERSATION.CARD_CONTEXT_MENU.API.TEAM_ASSIGNMENT.SUCCESFUL', {
        team: team.name,
        conversationId,
      })
    );
  } catch (error) {
    useAlert(t('CONVERSATION.CARD_CONTEXT_MENU.API.TEAM_ASSIGNMENT.FAILED'));
  }
}

function toggleConversationStatus(
  conversationId,
  status,
  snoozedUntil,
  customAttributes = null
) {
  const payload = {
    conversationId,
    status,
    snoozedUntil,
  };

  if (customAttributes) {
    payload.customAttributes = customAttributes;
  }

  store.dispatch('toggleStatus', payload).then(() => {
    useAlert(t('CONVERSATION.CHANGE_STATUS'));
  });
}

function handleResolveConversation(conversationId, status, snoozedUntil) {
  if (status !== wootConstants.STATUS_TYPE.RESOLVED) {
    toggleConversationStatus(conversationId, status, snoozedUntil);
    return;
  }

  // Check for required attributes before resolving
  const conversation = getConversationById.value(conversationId);
  const currentCustomAttributes = conversation?.custom_attributes || {};
  const { hasMissing, missing } = checkMissingAttributes(
    currentCustomAttributes
  );

  if (hasMissing) {
    // Pass conversation context through the modal's API
    const conversationContext = {
      id: conversationId,
      snoozedUntil,
    };
    resolveAttributesModalRef.value?.open(
      missing,
      currentCustomAttributes,
      conversationContext
    );
  } else {
    toggleConversationStatus(conversationId, status, snoozedUntil);
  }
}

function handleResolveWithAttributes({ attributes, context }) {
  if (context) {
    const existingConversation = getConversationById.value(context.id);
    const currentCustomAttributes =
      existingConversation?.custom_attributes || {};
    const mergedAttributes = { ...currentCustomAttributes, ...attributes };

    toggleConversationStatus(
      context.id,
      wootConstants.STATUS_TYPE.RESOLVED,
      context.snoozedUntil,
      mergedAttributes
    );
  }
}

function allSelectedConversationsStatus(status) {
  if (!selectedConversations.value.length) return false;
  return selectedConversations.value.every(item => {
    return getConversationById.value(item)?.status === status;
  });
}

function toggleSelectAll(check) {
  selectAllConversations(check, conversationList);
}

useEmitter('fetch_conversation_stats', () => {
  if (hasAppliedFiltersOrActiveFolders.value) return;
  store.dispatch('conversationStats/get', conversationFilters.value);
});

// Nothing left to show on the archived screen: go back to the normal list.
watch(
  () => archivedIds.value.size,
  size => {
    if (size === 0 && archivedOnly.value) closeArchived();
  }
);

onMounted(() => {
  store.dispatch('setChatListFilters', conversationFilters.value);
  setFiltersFromUISettings();
  store.dispatch('setChatStatusFilter', activeStatus.value);
  store.dispatch('setChatSortFilter', activeSortBy.value);
  if (!applyRouteFilters()) resetAndFetchData();
  fetchArchivedState();
  if (hasActiveFolders.value) {
    store.dispatch('campaigns/get');
  }
});

const deleteConversationDialogRef = ref(null);
const selectedConversationId = ref(null);

async function deleteConversation() {
  try {
    await store.dispatch('deleteConversation', selectedConversationId.value);
    redirectToConversationList();
    selectedConversationId.value = null;
    deleteConversationDialogRef.value.close();
    useAlert(t('CONVERSATION.SUCCESS_DELETE_CONVERSATION'));
  } catch (error) {
    useAlert(t('CONVERSATION.FAIL_DELETE_CONVERSATION'));
  }
}

const handleDelete = conversationId => {
  selectedConversationId.value = conversationId;
  deleteConversationDialogRef.value.open();
};

provide('selectConversation', selectConversation);
provide('deSelectConversation', deSelectConversation);
provide('assignAgent', onAssignAgent);
provide('assignTeam', onAssignTeam);
provide('assignLabels', onAssignLabels);
provide('removeLabels', onRemoveLabels);
provide('updateConversationStatus', handleResolveConversation);
provide('markAsUnread', markAsUnread);
provide('markAsRead', markAsRead);
provide('toggleConversationPin', toggleConversationPin);
provide('toggleConversationArchive', toggleConversationArchive);
provide('assignPriority', assignPriority);
provide('isConversationSelected', isConversationSelected);
provide('deleteConversation', handleDelete);

watch(activeTeam, () => resetAndFetchData());

watch(
  computed(() => props.conversationInbox),
  () => resetAndFetchData()
);
watch(
  computed(() => props.label),
  () => resetAndFetchData()
);
watch(
  computed(() => props.conversationType),
  () => resetAndFetchData()
);

watch(activeFolder, (newVal, oldVal) => {
  if (newVal !== oldVal) {
    store.dispatch('customViews/setActiveConversationFolder', newVal || null);
  }
  resetAndFetchData();
});

watch(chatLists, () => {
  chatsOnView.value = conversationList.value;
});

// Filters can be applied from outside the list, so clear the selection here.
watch(appliedFilters, () => resetBulkActions());
</script>

<template>
  <div
    class="flex flex-col flex-shrink-0 conversations-list-wrap bg-n-surface-1 relative"
    :class="[
      { hidden: !showConversationList },
      isOnExpandedLayout ? 'basis-full' : 'w-[340px] 2xl:w-[412px]',
    ]"
  >
    <slot />
    <div v-if="archivedOnly" data-testid="archived-header">
      <div class="flex h-[3.25rem] items-center gap-2 px-3">
        <button
          v-tooltip.right="t('CHAT_LIST.BACK_TO_LIST')"
          type="button"
          class="grid size-8 flex-shrink-0 place-content-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
          :aria-label="t('CHAT_LIST.BACK_TO_LIST')"
          data-testid="archived-back"
          @click="closeArchived"
        >
          <span class="i-lucide-arrow-left size-4" />
        </button>
        <h1 class="m-0 truncate text-lg font-medium text-n-slate-12">
          {{ t('CHAT_LIST.ARCHIVED_ONLY') }}
        </h1>
      </div>
      <p class="m-0 px-4 pb-2.5 text-xs text-n-slate-11">
        {{ t('CHAT_LIST.ARCHIVED_NOTE') }}
      </p>
    </div>
    <ChatListHeader
      v-else
      :page-title="pageTitle"
      :contact-filter="appliedContactFilter"
      :has-applied-filters="hasAppliedFilters"
      :has-active-folders="hasActiveFolders"
      :active-status="activeStatus"
      :is-on-expanded-layout="isOnExpandedLayout"
      :conversation-stats="conversationStats"
      :is-list-loading="chatListLoading && !conversationList.length"
      :voice-inbox-id="voiceInboxId"
      @add-folders="onClickOpenAddFoldersModal"
      @delete-folders="onClickOpenDeleteFoldersModal"
      @filters-modal="onToggleAdvanceFiltersModal"
      @reset-filters="resetFilters"
      @basic-filter-change="onBasicFilterChange"
    />

    <TeleportWithDirection
      v-if="showAddFoldersModal"
      to="#saveFilterTeleportTarget"
    >
      <SaveCustomView
        v-model="appliedFilter"
        :custom-views-query="foldersQuery"
        :open-last-saved-item="openLastSavedItemInFolder"
        @close="onCloseAddFoldersModal"
      />
    </TeleportWithDirection>

    <DeleteCustomViews
      v-if="showDeleteFoldersModal"
      v-model:show="showDeleteFoldersModal"
      :active-custom-view="activeFolder"
      :custom-views-id="foldersId"
      :open-last-item-after-delete="openLastItemAfterDeleteInFolder"
      @close="onCloseDeleteFoldersModal"
    />

    <ChatTypeTabs
      v-if="!hasAppliedFiltersOrActiveFolders && !archivedOnly"
      :items="assigneeTabItems"
      :active-tab="activeAssigneeTab"
      is-compact
      @chat-tab-change="updateAssigneeTab"
    />

    <div
      v-if="!hasAppliedFiltersOrActiveFolders && !archivedOnly"
      class="px-3 pt-1 pb-2 flex gap-2"
      role="group"
      :aria-label="t('CHAT_LIST.QUICK_FILTERS')"
    >
      <button
        v-for="chip in quickFilters"
        :key="chip.key"
        type="button"
        class="flex h-8 min-w-0 flex-1 basis-0 items-center justify-center gap-1.5 rounded-lg outline outline-1 -outline-offset-1 px-2 text-xs font-medium transition-colors duration-150 focus-visible:outline-2 focus-visible:outline-n-brand"
        :class="
          chip.active
            ? 'outline-n-brand/40 bg-n-brand/10 text-n-brand'
            : 'outline-n-weak text-n-slate-11 hover:bg-n-alpha-1 hover:text-n-slate-12'
        "
        :aria-pressed="chip.active"
        @click="toggleQuickFilter(chip.key)"
      >
        <span :class="chip.icon" class="size-4 flex-shrink-0" />
        <span class="truncate">{{ chip.label }}</span>
      </button>
    </div>

    <!-- Sits like the first row of the list (icon in the avatar column), as in the WhatsApp app. -->
    <button
      v-if="
        !hasAppliedFiltersOrActiveFolders && !archivedOnly && archivedIds.size
      "
      type="button"
      class="flex h-12 flex-shrink-0 items-center gap-2 border-b border-n-slate-3 px-3 text-start transition-colors duration-150 hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3 focus-visible:outline focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-n-brand"
      data-testid="archived-entry"
      @click="openArchived"
    >
      <span class="grid w-10 flex-shrink-0 place-content-center text-n-brand">
        <span class="i-lucide-archive size-4" />
      </span>
      <span class="flex-1 text-sm font-medium text-n-slate-12">
        {{ t('CHAT_LIST.ARCHIVED_ONLY') }}
      </span>
      <!-- Only the archived conversations that have new messages are counted -->
      <span
        v-if="archivedUnreadCount"
        class="inline-grid h-5 min-w-5 place-items-center rounded-full bg-n-brand px-1.5 text-xs font-semibold leading-3 text-white dark:text-n-slate-1 tabular-nums"
        data-testid="archived-unread"
      >
        {{ archivedUnreadCount }}
      </span>
    </button>

    <div
      v-if="!chatListLoading && !conversationList.length"
      class="flex flex-col items-center gap-3 px-6 py-10 text-center"
      data-testid="chat-list-empty"
    >
      <p class="m-0 text-sm text-n-slate-11">{{ emptyStateText }}</p>
      <NextButton
        v-if="unreadOnly || awaitingReplyOnly"
        :label="t('CHAT_LIST.EMPTY_STATE.SHOW_ALL')"
        slate
        faded
        sm
        @click="clearQuickFilters"
      />
    </div>
    <ConversationBulkActions
      :conversations="selectedConversations"
      :all-conversations-selected="allConversationsSelected"
      :selected-inboxes="uniqueInboxes"
      :show-open-action="allSelectedConversationsStatus('open')"
      :show-resolved-action="allSelectedConversationsStatus('resolved')"
      :show-snoozed-action="allSelectedConversationsStatus('snoozed')"
      :class="isOnExpandedLayout && 'sm:!w-[24rem] !w-full'"
      @select-all-conversations="toggleSelectAll"
    />
    <ConversationList
      :conversation-list="conversationList"
      :is-loading="chatListLoading"
      :show-end-of-list-message="showEndOfListMessage"
      :label="label"
      :team-id="teamId"
      :folders-id="foldersId"
      :conversation-type="conversationType"
      :show-assignee="showAssigneeInConversationCard"
      :is-on-expanded-layout="isOnExpandedLayout"
      @load-more="loadMoreConversations"
    />
    <Dialog
      ref="deleteConversationDialogRef"
      type="alert"
      :title="
        $t('CONVERSATION.DELETE_CONVERSATION.TITLE', {
          conversationId: selectedConversationId,
        })
      "
      :description="$t('CONVERSATION.DELETE_CONVERSATION.DESCRIPTION')"
      :confirm-button-label="$t('CONVERSATION.DELETE_CONVERSATION.CONFIRM')"
      @confirm="deleteConversation"
      @close="selectedConversationId = null"
    />
    <TeleportWithDirection
      v-if="showAdvancedFilters"
      to="#conversationFilterTeleportTarget"
    >
      <ConversationFilter
        v-model="appliedFilter"
        :folder-name="activeFolderName"
        :is-folder-view="hasActiveFolders"
        @apply-filter="onApplyFilter"
        @update-folder="onUpdateSavedFilter"
        @close="closeAdvanceFiltersModal"
      />
    </TeleportWithDirection>
    <ConversationResolveAttributesModal
      ref="resolveAttributesModalRef"
      @submit="handleResolveWithAttributes"
    />
  </div>
</template>

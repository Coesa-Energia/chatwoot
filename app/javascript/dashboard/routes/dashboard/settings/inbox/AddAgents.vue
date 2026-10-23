<script>
/* eslint no-console: 0 */
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

import InboxMembersAPI from '../../../../api/inboxMembers';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import router from '../../../index';
import PageHeader from '../SettingsSubPageHeader.vue';
import InboxAgentAccess from './InboxAgentAccess.vue';
import InboxAgentRotation from './InboxAgentRotation.vue';
import InboxDefaultTeam from './InboxDefaultTeam.vue';
import { useVuelidate } from '@vuelidate/core';

export default {
  components: {
    PageHeader,
    NextButton,
    TagInput,
    InboxAgentAccess,
    InboxAgentRotation,
    InboxDefaultTeam,
  },
  validations: {
    selectedAgentIds: {
      isEmpty() {
        return !!this.selectedAgentIds.length;
      },
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      selectedAgentIds: [],
      seeAllAgentIds: [],
      rotationAgentIds: [],
      defaultTeamId: null,
      isCreating: false,
    };
  },
  computed: {
    ...mapGetters({
      agentList: 'agents/getAgents',
    }),
    selectedAgentNames() {
      return this.selectedAgentIds.map(
        id => this.agentList.find(a => a.id === id)?.name ?? ''
      );
    },
    selectedAgents() {
      return this.selectedAgentIds
        .map(id => this.agentList.find(a => a.id === id))
        .filter(Boolean);
    },
    agentMenuItems() {
      return this.agentList
        .filter(({ id }) => !this.selectedAgentIds.includes(id))
        .map(({ id, name, thumbnail, avatar_url }) => ({
          label: name,
          value: id,
          action: 'select',
          thumbnail: { name, src: thumbnail || avatar_url || '' },
        }));
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
  },
  methods: {
    handleAgentAdd({ value }) {
      if (!this.selectedAgentIds.includes(value)) {
        this.selectedAgentIds.push(value);
        this.rotationAgentIds.push(value);
      }
    },
    handleAgentRemove(index) {
      const [removedId] = this.selectedAgentIds.splice(index, 1);
      this.seeAllAgentIds = this.seeAllAgentIds.filter(id => id !== removedId);
      this.rotationAgentIds = this.rotationAgentIds.filter(
        id => id !== removedId
      );
    },
    async addAgents() {
      this.isCreating = true;
      const inboxId = this.$route.params.inbox_id;

      try {
        await InboxMembersAPI.update({
          inboxId,
          agentList: this.selectedAgentIds,
          seeAllIds: this.seeAllAgentIds,
          rotationIds: this.rotationAgentIds,
        });
        if (this.defaultTeamId) {
          await this.$store.dispatch('inboxes/updateInbox', {
            id: inboxId,
            formData: false,
            default_team_id: this.defaultTeamId,
          });
        }
        router.replace({
          name: 'settings_inbox_finish',
          params: {
            page: 'new',
            inbox_id: this.$route.params.inbox_id,
          },
        });
      } catch (error) {
        useAlert(error.message);
      }
      this.isCreating = false;
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <form class="flex flex-wrap flex-col mx-0" @submit.prevent="addAgents()">
      <div class="w-full">
        <PageHeader
          :header-title="$t('INBOX_MGMT.ADD.AGENTS.TITLE')"
          :header-content="$t('INBOX_MGMT.ADD.AGENTS.DESC')"
        />
      </div>
      <div>
        <div class="w-full mb-4">
          <label :class="{ error: v$.selectedAgentIds.$error }">
            {{ $t('INBOX_MGMT.ADD.AGENTS.TITLE') }}
            <div
              data-testid="agent-selector"
              class="rounded-xl outline outline-1 -outline-offset-1 outline-n-weak hover:outline-n-strong px-2 py-2"
            >
              <TagInput
                :model-value="selectedAgentNames"
                :placeholder="$t('INBOX_MGMT.ADD.AGENTS.PICK_AGENTS')"
                :menu-items="agentMenuItems"
                show-dropdown
                skip-label-dedup
                @add="handleAgentAdd"
                @remove="handleAgentRemove"
              />
            </div>
            <span v-if="v$.selectedAgentIds.$error" class="message">
              {{ $t('INBOX_MGMT.ADD.AGENTS.VALIDATION_ERROR') }}
            </span>
          </label>
        </div>
        <InboxAgentAccess
          v-model="seeAllAgentIds"
          :agents="selectedAgents"
          class="mb-4"
        />
        <InboxAgentRotation
          v-model="rotationAgentIds"
          :agents="selectedAgents"
          class="mb-4"
        />
        <InboxDefaultTeam v-model="defaultTeamId" class="mb-4" />
        <div class="w-full">
          <NextButton
            type="submit"
            :is-loading="isCreating"
            solid
            blue
            :label="$t('INBOX_MGMT.AGENTS.BUTTON_TEXT')"
          />
        </div>
      </div>
    </form>
  </div>
</template>

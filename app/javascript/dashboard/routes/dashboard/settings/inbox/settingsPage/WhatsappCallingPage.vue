<script>
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TextArea from 'next/textarea/TextArea.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CallRecordingSettings from './CallRecordingSettings.vue';
import CallPermissionTemplateSection from './CallPermissionTemplateSection.vue';
import CallMessagePreview from './CallMessagePreview.vue';

export default {
  components: {
    SettingsToggleSection,
    NextButton,
    TextArea,
    Spinner,
    CallRecordingSettings,
    CallPermissionTemplateSection,
    CallMessagePreview,
  },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      callingEnabled: this.inbox.provider_config?.calling_enabled || false,
      inboundCallsEnabled:
        this.inbox.provider_config?.inbound_calls_enabled !== false,
      permissionRequestBody:
        this.inbox.provider_config?.call_permission_request_body || '',
      isUpdating: false,
      isTogglingCalling: false,
      isTogglingInbound: false,
      // undefined while the template panel loads, null when no template exists yet.
      templateStatus: undefined,
    };
  },
  computed: {
    rules() {
      return [1, 2, 3, 4, 5].map(number =>
        this.$t(`INBOX_MGMT.WHATSAPP_CALLING.RULES.ITEM_${number}`)
      );
    },
    defaultMessagePreview() {
      return (
        this.permissionRequestBody.trim() ||
        this.$t(
          'INBOX_MGMT.WHATSAPP_CALLING.PERMISSION_REQUEST_BODY.PLACEHOLDER'
        )
      );
    },
    showNoTemplateWarning() {
      return (
        this.templateStatus !== undefined && this.templateStatus !== 'APPROVED'
      );
    },
    phoneNumber() {
      return (
        this.inbox.provider_config?.phone_number || this.inbox.phone_number
      );
    },
  },
  watch: {
    'inbox.provider_config.calling_enabled'(val) {
      this.callingEnabled = val || false;
    },
    'inbox.provider_config.call_permission_request_body'(val) {
      this.permissionRequestBody = val || '';
    },
    'inbox.provider_config.inbound_calls_enabled'(val) {
      this.inboundCallsEnabled = val !== false;
    },
  },
  methods: {
    async handleInboundToggle(newValue) {
      if (this.isTogglingInbound) return;
      const previousValue = this.inboundCallsEnabled;
      this.inboundCallsEnabled = newValue;
      this.isTogglingInbound = true;
      try {
        await InboxesAPI.setInboundCalls(this.inbox.id, newValue);
        await this.$store.dispatch('inboxes/get', this.inbox.id);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (_) {
        this.inboundCallsEnabled = previousValue;
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      } finally {
        this.isTogglingInbound = false;
      }
    },
    async handleCallingToggle(newValue) {
      if (this.isTogglingCalling) return;
      const previousValue = this.callingEnabled;
      this.callingEnabled = newValue;
      this.isTogglingCalling = true;
      try {
        if (newValue) {
          await InboxesAPI.enableWhatsappCalling(this.inbox.id);
        } else {
          await InboxesAPI.disableWhatsappCalling(this.inbox.id);
        }
        await this.$store.dispatch('inboxes/get', this.inbox.id);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (_) {
        this.callingEnabled = previousValue;
        const fallbackKey = newValue
          ? 'INBOX_MGMT.WHATSAPP_CALLING.ENABLE_FAILED'
          : 'INBOX_MGMT.EDIT.API.ERROR_MESSAGE';
        useAlert(this.$t(fallbackKey));
      } finally {
        this.isTogglingCalling = false;
      }
    },
    async updateCallingSettings() {
      this.isUpdating = true;
      try {
        // provider_config is saved whole, so start from what the server has now: the template panel
        // updates its own key in the background and a stale copy from the store would wipe it.
        const { data: freshInbox } = await InboxesAPI.show(this.inbox.id);
        await this.$store.dispatch('inboxes/updateInbox', {
          id: this.inbox.id,
          formData: false,
          channel: {
            provider_config: {
              ...(freshInbox?.provider_config || this.inbox.provider_config),
              call_permission_request_body:
                this.permissionRequestBody.trim() || null,
            },
          },
        });
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        const message =
          error?.response?.data?.message ||
          this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE');
        useAlert(message);
      } finally {
        this.isUpdating = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-8">
    <section class="flex flex-col gap-3">
      <h3 class="text-base font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.WHATSAPP_CALLING.SECTIONS.GENERAL') }}
      </h3>
      <div
        class="relative"
        :class="{ 'pointer-events-none opacity-60': isTogglingCalling }"
      >
        <SettingsToggleSection
          :model-value="callingEnabled"
          :header="$t('INBOX_MGMT.WHATSAPP_CALLING.ENABLE.LABEL')"
          :description="$t('INBOX_MGMT.WHATSAPP_CALLING.ENABLE.DESCRIPTION')"
          :hide-toggle="isTogglingCalling"
          @update:model-value="handleCallingToggle"
        >
          <template v-if="isTogglingCalling" #hiddenToggle>
            <Spinner class="size-4 text-n-slate-11" />
          </template>
          <p
            v-if="callingEnabled && phoneNumber"
            class="flex items-center gap-1.5 px-4 pt-1 text-sm text-n-slate-11"
          >
            <span class="i-lucide-phone size-3.5" />
            {{
              $t('INBOX_MGMT.WHATSAPP_CALLING.PHONE_NUMBER.INLINE', {
                number: phoneNumber,
              })
            }}
          </p>
        </SettingsToggleSection>
      </div>

      <template v-if="callingEnabled">
        <div
          class="relative"
          :class="{ 'pointer-events-none opacity-60': isTogglingInbound }"
        >
          <SettingsToggleSection
            :model-value="inboundCallsEnabled"
            :header="$t('INBOX_MGMT.VOICE_CONFIGURATION.INBOUND.LABEL')"
            :description="
              $t('INBOX_MGMT.VOICE_CONFIGURATION.INBOUND.DESCRIPTION')
            "
            :hide-toggle="isTogglingInbound"
            @update:model-value="handleInboundToggle"
          >
            <template v-if="isTogglingInbound" #hiddenToggle>
              <Spinner class="size-4 text-n-slate-11" />
            </template>
          </SettingsToggleSection>
        </div>

        <CallRecordingSettings :inbox="inbox" />
      </template>
    </section>

    <section v-if="callingEnabled" class="flex flex-col gap-4">
      <div class="flex flex-col gap-1">
        <h3 class="text-base font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.WHATSAPP_CALLING.SECTIONS.PERMISSION') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{
            $t('INBOX_MGMT.WHATSAPP_CALLING.SECTIONS.PERMISSION_DESCRIPTION')
          }}
        </p>
      </div>

      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div class="flex gap-3 p-3 rounded-xl bg-n-alpha-1">
          <span
            class="grid rounded-lg shrink-0 size-8 place-items-center bg-n-teal-3 text-n-teal-11"
          >
            <span class="i-lucide-message-circle size-4" />
          </span>
          <div class="flex flex-col gap-0.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('INBOX_MGMT.WHATSAPP_CALLING.FLOW.INSIDE_TITLE') }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ $t('INBOX_MGMT.WHATSAPP_CALLING.FLOW.INSIDE_DESC') }}
            </span>
          </div>
        </div>
        <div class="flex gap-3 p-3 rounded-xl bg-n-alpha-1">
          <span
            class="grid rounded-lg shrink-0 size-8 place-items-center bg-n-amber-3 text-n-amber-11"
          >
            <span class="i-lucide-file-text size-4" />
          </span>
          <div class="flex flex-col gap-0.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('INBOX_MGMT.WHATSAPP_CALLING.FLOW.OUTSIDE_TITLE') }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ $t('INBOX_MGMT.WHATSAPP_CALLING.FLOW.OUTSIDE_DESC') }}
            </span>
          </div>
        </div>
      </div>

      <p
        v-if="showNoTemplateWarning"
        class="flex items-start gap-2 px-3 py-2 text-sm rounded-lg bg-n-amber-2 text-n-amber-11"
        data-testid="call-permission-no-template-warning"
      >
        <span class="i-lucide-triangle-alert size-4 mt-0.5 shrink-0" />
        {{ $t('INBOX_MGMT.WHATSAPP_CALLING.FLOW.NO_TEMPLATE') }}
      </p>

      <div class="grid items-start grid-cols-1 gap-4 xl:grid-cols-2">
        <section
          class="flex flex-col gap-4 p-4 border rounded-xl border-n-weak bg-n-solid-1"
          data-testid="call-permission-default-message"
        >
          <header class="flex flex-col gap-0.5">
            <h4 class="text-sm font-medium text-n-slate-12">
              {{
                $t('INBOX_MGMT.WHATSAPP_CALLING.PERMISSION_REQUEST_BODY.LABEL')
              }}
            </h4>
            <p class="text-xs text-n-slate-11">
              {{
                $t(
                  'INBOX_MGMT.WHATSAPP_CALLING.PERMISSION_REQUEST_BODY.PANEL_HINT'
                )
              }}
            </p>
          </header>
          <TextArea
            v-model="permissionRequestBody"
            :placeholder="
              $t(
                'INBOX_MGMT.WHATSAPP_CALLING.PERMISSION_REQUEST_BODY.PLACEHOLDER'
              )
            "
            auto-height
            resize
          />
          <CallMessagePreview
            :label="
              $t('INBOX_MGMT.WHATSAPP_CALLING.PERMISSION_REQUEST_BODY.PREVIEW')
            "
            :body="defaultMessagePreview"
            :button-label="
              $t(
                'INBOX_MGMT.WHATSAPP_CALLING.PERMISSION_TEMPLATE.PREVIEW_BUTTON'
              )
            "
          />
          <div>
            <NextButton
              sm
              :is-loading="isUpdating"
              :label="
                $t('INBOX_MGMT.WHATSAPP_CALLING.PERMISSION_REQUEST_BODY.SAVE')
              "
              @click="updateCallingSettings"
            />
          </div>
        </section>

        <CallPermissionTemplateSection
          :inbox-id="inbox.id"
          @status-change="templateStatus = $event"
        />
      </div>
    </section>

    <details
      v-if="callingEnabled"
      class="border group rounded-xl border-n-weak bg-n-solid-1"
      data-testid="call-rules"
    >
      <summary
        class="flex items-center justify-between gap-3 px-4 py-3 text-sm font-medium list-none cursor-pointer select-none text-n-slate-12 [&::-webkit-details-marker]:hidden"
      >
        <span class="flex items-center gap-2">
          <span class="i-lucide-info size-4 text-n-slate-11" />
          {{ $t('INBOX_MGMT.WHATSAPP_CALLING.RULES.TOGGLE') }}
        </span>
        <span
          class="transition-transform i-lucide-chevron-down size-4 text-n-slate-11 group-open:rotate-180"
        />
      </summary>
      <div class="flex flex-col gap-3 px-4 pb-4 text-sm text-n-slate-11">
        <p>{{ $t('INBOX_MGMT.WHATSAPP_CALLING.RULES.DESCRIPTION') }}</p>
        <ul class="flex flex-col gap-2 pl-5 list-disc text-n-slate-12">
          <li v-for="(rule, index) in rules" :key="index">
            {{ rule }}
          </li>
        </ul>
        <p>{{ $t('INBOX_MGMT.WHATSAPP_CALLING.HOW_IT_WORKS.DESCRIPTION') }}</p>
      </div>
    </details>
  </div>
</template>

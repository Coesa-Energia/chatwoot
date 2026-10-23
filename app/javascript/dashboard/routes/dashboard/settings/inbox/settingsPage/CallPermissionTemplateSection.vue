<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import CallMessagePreview from './CallMessagePreview.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'next/textarea/TextArea.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

// The WhatsApp template used to ask a customer for call permission. The admin can read it, edit the text
// and send it to Meta for approval, adopt one that already exists by typing its name, and re-check approval.
const props = defineProps({
  inboxId: { type: Number, required: true },
});

// Lets the page warn when there is no approved template to reach customers outside the 24h window.
const emit = defineEmits(['statusChange']);

const { t } = useI18n();

const template = ref(null);
const isLoading = ref(true);
const isSaving = ref(false);
const isRefreshing = ref(false);
const isEditing = ref(false);
const form = reactive({ name: '', body: '' });

const KNOWN_STATUSES = [
  'PENDING',
  'APPROVED',
  'REJECTED',
  'PAUSED',
  'NOT_FOUND',
];
const BASE = 'INBOX_MGMT.WHATSAPP_CALLING.PERMISSION_TEMPLATE';

// Meta decides the category (we submit as Utility and allow it to switch to Marketing).
const categoryLabel = computed(() => {
  const category = template.value?.category;
  if (category === 'UTILITY') return t(`${BASE}.CATEGORY.UTILITY`);
  if (category === 'MARKETING') return t(`${BASE}.CATEGORY.MARKETING`);
  return category || '';
});

const exists = computed(() => !!template.value?.created);
// The editor is open while nothing exists yet, or when the admin asked for a new version.
const showEditor = computed(() => !exists.value || isEditing.value);
const status = computed(() => template.value?.status);
const isApproved = computed(() => status.value === 'APPROVED');

const statusLabel = computed(() => {
  if (!exists.value) return t(`${BASE}.STATUS.NONE`);
  if (KNOWN_STATUSES.includes(status.value)) {
    return t(`${BASE}.STATUS.${status.value}`);
  }
  return t(`${BASE}.STATUS.OTHER`, { status: status.value });
});

const previewBody = computed(() =>
  showEditor.value ? form.body : template.value?.body || ''
);

// pedido_x -> pedido_x_v2 -> pedido_x_v3
const nextVersionName = name => {
  const match = name.match(/^(.*)_v(\d+)$/);
  return match ? `${match[1]}_v${Number(match[2]) + 1}` : `${name}_v2`;
};

const fillForm = ({ forNewVersion } = {}) => {
  const current = template.value || {};
  form.body = current.body || current.default_body || '';
  const base = current.name || '';
  form.name = forNewVersion ? nextVersionName(base) : base;
};

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await InboxesAPI.getCallPermissionTemplate(props.inboxId);
    template.value = data;
    fillForm();
    emit('statusChange', data.created ? data.status : null);
  } catch (error) {
    useAlert(t(`${BASE}.LOAD_FAILED`));
  } finally {
    isLoading.value = false;
  }
};

const errorText = error => error?.response?.data?.error || '';

const startNewVersion = () => {
  fillForm({ forNewVersion: true });
  isEditing.value = true;
};

const cancelEditing = () => {
  fillForm();
  isEditing.value = false;
};

const save = async () => {
  if (isSaving.value) return;
  isSaving.value = true;
  try {
    const { data } = await InboxesAPI.createCallPermissionTemplate(
      props.inboxId,
      { name: form.name, body: form.body }
    );
    template.value = data;
    fillForm();
    isEditing.value = false;
    emit('statusChange', data.status);
    useAlert(
      t(`${BASE}.RESULT.${data.status === 'APPROVED' ? 'APPROVED' : 'SENT'}`)
    );
  } catch (error) {
    useAlert(t(`${BASE}.FAILED`, { error: errorText(error) }));
  } finally {
    isSaving.value = false;
  }
};

const check = async () => {
  if (isRefreshing.value) return;
  isRefreshing.value = true;
  try {
    const { data } = await InboxesAPI.refreshCallPermissionTemplate(
      props.inboxId
    );
    template.value = data;
    emit('statusChange', data.created ? data.status : null);
    const key = KNOWN_STATUSES.includes(data.status) ? data.status : 'OTHER';
    useAlert(t(`${BASE}.RESULT.${key}`, { status: data.status }));
  } catch (error) {
    useAlert(t(`${BASE}.CHECK_FAILED`, { error: errorText(error) }));
  } finally {
    isRefreshing.value = false;
  }
};

onMounted(load);
</script>

<template>
  <section
    class="flex flex-col gap-4 p-4 rounded-xl border border-n-weak bg-n-solid-1"
    data-testid="call-permission-template"
  >
    <header class="flex items-start justify-between gap-3">
      <div class="flex flex-col gap-0.5 min-w-0">
        <h4 class="text-sm font-medium text-n-slate-12">
          {{ t(`${BASE}.LABEL`) }}
        </h4>
        <p class="text-xs text-n-slate-11">
          {{ t(`${BASE}.PANEL_HINT`) }}
        </p>
      </div>
      <span
        v-if="!isLoading"
        class="shrink-0 px-2 py-0.5 text-xs font-medium rounded-full"
        :class="
          isApproved
            ? 'bg-n-teal-3 text-n-teal-11'
            : status === 'REJECTED'
              ? 'bg-n-ruby-3 text-n-ruby-11'
              : 'bg-n-amber-3 text-n-amber-11'
        "
        data-testid="call-permission-template-status"
      >
        {{ statusLabel }}
      </span>
    </header>

    <div v-if="isLoading" class="flex py-4 justify-center text-n-slate-11">
      <Spinner class="size-4" />
    </div>
    <template v-else>
      <div
        v-if="exists"
        class="flex flex-wrap items-center justify-between gap-2 px-3 py-2 rounded-lg bg-n-alpha-1"
      >
        <div class="flex flex-col min-w-0 text-xs text-n-slate-11">
          <span class="font-medium truncate text-n-slate-12">
            {{ template.name }} ({{ template.language }})
          </span>
          <span
            v-if="categoryLabel"
            data-testid="call-permission-template-category"
          >
            {{ t(`${BASE}.CATEGORY.ASSIGNED`, { category: categoryLabel }) }}
          </span>
        </div>
        <NextButton
          xs
          faded
          slate
          icon="i-lucide-refresh-cw"
          :is-loading="isRefreshing"
          :label="t(`${BASE}.REFRESH`)"
          @click="check"
        />
      </div>

      <p
        v-if="template.rejected_reason && status === 'REJECTED'"
        class="px-3 py-2 text-xs rounded-lg bg-n-ruby-2 text-n-ruby-11"
      >
        {{ t(`${BASE}.REJECTED_REASON`, { reason: template.rejected_reason }) }}
      </p>

      <div v-if="showEditor" class="flex flex-col gap-3">
        <Input
          v-model="form.name"
          size="sm"
          :label="t(`${BASE}.NAME.LABEL`)"
          :placeholder="template.name"
          :message="t(`${BASE}.NAME.HELP`)"
        />
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t(`${BASE}.BODY.LABEL`) }}
          </label>
          <TextArea v-model="form.body" auto-height resize />
          <p class="text-xs text-n-slate-11">
            {{ t(`${BASE}.BODY.HELP`, { count: form.body.length }) }}
          </p>
        </div>
      </div>

      <CallMessagePreview
        :label="t(`${BASE}.PREVIEW`)"
        :body="previewBody"
        :button-label="t(`${BASE}.PREVIEW_BUTTON`)"
        data-testid="call-permission-template-preview"
      />

      <div class="flex flex-wrap items-center gap-2 mt-auto">
        <template v-if="showEditor">
          <NextButton
            sm
            :is-loading="isSaving"
            :disabled="!form.body.trim() || !form.name.trim()"
            :label="t(`${BASE}.SEND`)"
            @click="save"
          />
          <NextButton
            v-if="exists"
            sm
            faded
            slate
            :label="t(`${BASE}.CANCEL`)"
            @click="cancelEditing"
          />
        </template>
        <NextButton
          v-else
          sm
          faded
          slate
          icon="i-lucide-pencil"
          :label="t(`${BASE}.NEW_VERSION`)"
          @click="startNewVersion"
        />
      </div>
      <p v-if="showEditor" class="text-xs text-n-slate-10">
        {{ t(`${BASE}.ADOPT_HINT`) }}
      </p>
    </template>
  </section>
</template>

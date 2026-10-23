<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { resolveBrandImage } from 'dashboard/components-next/sidebar/brandImages';
import { trimImageMargins } from 'dashboard/helper/trimImageMargins';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Logo from 'next/icon/Logo.vue';
import SectionLayout from './SectionLayout.vue';

const ACCEPTED_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];
const MAX_SIZE = 2 * 1024 * 1024;

const { t } = useI18n();
const store = useStore();
const { currentAccount } = useAccount();

const isSaving = ref(false);
const fileInputs = ref({});

const accountName = computed(() => currentAccount.value?.name || '');
const brandDisplay = computed(
  () => currentAccount.value?.brand_display || 'logo_name'
);
const textImage = computed(
  () => currentAccount.value?.brand_text_image || 'logo'
);
const showsTextImage = computed(() =>
  ['logo_name', 'logo_name_inline'].includes(brandDisplay.value)
);

// The two images the account can upload.
const uploaders = computed(() => [
  {
    field: 'logo',
    title: t('GENERAL_SETTINGS.FORM.BRAND.LOGO_MAIN'),
    url: currentAccount.value?.logo_url || '',
  },
  {
    field: 'collapsed_logo',
    title: t('GENERAL_SETTINGS.FORM.BRAND.TITLE_COLLAPSED'),
    note: t('GENERAL_SETTINGS.FORM.BRAND.NOTE_COLLAPSED'),
    url: currentAccount.value?.collapsed_logo_url || '',
  },
]);

const layouts = [
  { value: 'logo_name', label: 'LOGO_NAME' },
  { value: 'logo_name_inline', label: 'LOGO_NAME_INLINE' },
  { value: 'logo', label: 'LOGO' },
  { value: 'name', label: 'NAME' },
];

const textImages = computed(() => [
  {
    value: 'logo',
    label: t('GENERAL_SETTINGS.FORM.BRAND.TEXT_IMAGE_MAIN'),
    url: resolveBrandImage(currentAccount.value, 'main'),
  },
  {
    value: 'collapsed_logo',
    label: t('GENERAL_SETTINGS.FORM.BRAND.TEXT_IMAGE_COLLAPSED'),
    url: resolveBrandImage(currentAccount.value, 'collapsed'),
  },
]);

// Image shown in the layout previews, following the account's choice.
const previewImage = layout =>
  resolveBrandImage(currentAccount.value, layout === 'logo' ? 'main' : 'text');

const run = async action => {
  isSaving.value = true;
  try {
    await action();
    useAlert(t('GENERAL_SETTINGS.FORM.BRAND.UPDATE_SUCCESS'));
  } catch {
    useAlert(t('GENERAL_SETTINGS.FORM.BRAND.UPDATE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const upload = (field, file) =>
  run(async () => {
    // Empty margins make a logo look tiny in the sidebar, so they are cropped before uploading.
    const prepared = await trimImageMargins(file);
    if (prepared.size > MAX_SIZE) throw new Error('too big');
    await store.dispatch('accounts/updateLogo', { file: prepared, field });
  });

const onFileChange = (field, event) => {
  const [file] = event.target.files || [];
  event.target.value = '';
  if (!file) return;
  if (!ACCEPTED_TYPES.includes(file.type) || file.size > MAX_SIZE) {
    useAlert(t('GENERAL_SETTINGS.FORM.BRAND.FILE_ERROR'));
    return;
  }
  upload(field, file);
};

// Crops the margins of an image that is already uploaded.
const trimUploaded = async uploader => {
  try {
    const blob = await (await fetch(uploader.url)).blob();
    await upload(
      uploader.field,
      new File([blob], `${uploader.field}.png`, { type: blob.type })
    );
  } catch {
    useAlert(t('GENERAL_SETTINGS.FORM.BRAND.UPDATE_ERROR'));
  }
};

const removeImage = field =>
  run(() => store.dispatch('accounts/updateLogo', { file: null, field }));

const updateSetting = (key, value, current) => {
  if (value === current) return;
  run(() => store.dispatch('accounts/update', { [key]: value }));
};
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.BRAND.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.BRAND.NOTE')"
    with-border
  >
    <div class="grid gap-6">
      <div class="grid gap-4 sm:grid-cols-2">
        <div
          v-for="uploader in uploaders"
          :key="uploader.field"
          class="flex items-center gap-4"
        >
          <div
            class="grid size-16 flex-shrink-0 place-content-center overflow-hidden rounded-2xl bg-n-alpha-1 outline outline-1 outline-n-weak"
          >
            <img
              v-if="uploader.url"
              :src="uploader.url"
              :alt="uploader.title"
              class="size-full object-contain"
              :data-testid="`brand-preview-${uploader.field}`"
            />
            <Logo v-else class="size-8 opacity-60" />
          </div>
          <div class="grid min-w-0 gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ uploader.title }}
            </span>
            <div class="flex flex-wrap items-center gap-2">
              <NextButton
                slate
                faded
                sm
                :is-loading="isSaving"
                :label="
                  uploader.url
                    ? t('GENERAL_SETTINGS.FORM.BRAND.REPLACE')
                    : t('GENERAL_SETTINGS.FORM.BRAND.UPLOAD')
                "
                @click="fileInputs[uploader.field].click()"
              />
              <NextButton
                v-if="uploader.url"
                slate
                ghost
                sm
                :disabled="isSaving"
                :label="t('GENERAL_SETTINGS.FORM.BRAND.TRIM')"
                :data-testid="`brand-trim-${uploader.field}`"
                @click="trimUploaded(uploader)"
              />
              <NextButton
                v-if="uploader.url"
                ruby
                ghost
                sm
                :disabled="isSaving"
                :label="t('GENERAL_SETTINGS.FORM.BRAND.REMOVE')"
                @click="removeImage(uploader.field)"
              />
            </div>
            <p v-if="uploader.note" class="m-0 text-xs text-n-slate-11">
              {{ uploader.note }}
            </p>
          </div>
          <input
            :ref="el => (fileInputs[uploader.field] = el)"
            type="file"
            class="hidden"
            accept="image/png,image/jpeg,image/webp,image/gif"
            :data-testid="`brand-input-${uploader.field}`"
            @change="onFileChange(uploader.field, $event)"
          />
        </div>
      </div>
      <p class="m-0 -mt-3 text-sm text-n-slate-11">
        {{ t('GENERAL_SETTINGS.FORM.BRAND.HINT') }}
      </p>

      <fieldset class="m-0 grid gap-2 border-0 p-0">
        <legend class="mb-2 p-0 text-sm font-medium text-n-slate-12">
          {{ t('GENERAL_SETTINGS.FORM.BRAND.DISPLAY') }}
        </legend>
        <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <button
            v-for="layout in layouts"
            :key="layout.value"
            type="button"
            role="radio"
            :aria-checked="brandDisplay === layout.value"
            :disabled="isSaving"
            :data-testid="`brand-display-${layout.value}`"
            class="grid gap-3 rounded-xl outline outline-1 -outline-offset-1 p-3 text-start transition-colors"
            :class="
              brandDisplay === layout.value
                ? 'outline-n-brand bg-n-brand/5'
                : 'outline-n-weak hover:outline-n-strong'
            "
            @click="updateSetting('brand_display', layout.value, brandDisplay)"
          >
            <!-- Mini preview of the sidebar header -->
            <div
              class="grid h-16 content-center justify-items-center gap-1 overflow-hidden rounded-lg bg-n-alpha-1 px-2"
              :class="{
                'grid-flow-col gap-2': layout.value === 'logo_name_inline',
              }"
              aria-hidden="true"
            >
              <template v-if="layout.value !== 'name'">
                <img
                  v-if="previewImage(layout.value)"
                  :src="previewImage(layout.value)"
                  class="w-auto max-w-full flex-shrink-0 rounded object-contain"
                  :class="layout.value === 'logo' ? 'h-8' : 'h-6'"
                />
                <Logo v-else class="size-6 flex-shrink-0" />
              </template>
              <span
                v-if="layout.value !== 'logo'"
                class="max-w-full truncate text-xs font-medium text-n-slate-12"
              >
                {{ accountName }}
              </span>
            </div>
            <span class="text-sm text-n-slate-12">
              {{
                t(`GENERAL_SETTINGS.FORM.BRAND.DISPLAY_OPTIONS.${layout.label}`)
              }}
            </span>
          </button>
        </div>
      </fieldset>

      <fieldset
        v-if="showsTextImage"
        class="m-0 grid gap-2 border-0 p-0"
        data-testid="brand-text-image"
      >
        <legend class="mb-2 p-0 text-sm font-medium text-n-slate-12">
          {{ t('GENERAL_SETTINGS.FORM.BRAND.TEXT_IMAGE') }}
        </legend>
        <div class="grid gap-3 sm:grid-cols-2">
          <button
            v-for="option in textImages"
            :key="option.value"
            type="button"
            role="radio"
            :aria-checked="textImage === option.value"
            :disabled="isSaving"
            :data-testid="`brand-text-image-${option.value}`"
            class="flex items-center gap-3 rounded-xl outline outline-1 -outline-offset-1 p-3 text-start transition-colors"
            :class="
              textImage === option.value
                ? 'outline-n-brand bg-n-brand/5'
                : 'outline-n-weak hover:outline-n-strong'
            "
            @click="updateSetting('brand_text_image', option.value, textImage)"
          >
            <span
              class="grid size-10 flex-shrink-0 place-content-center overflow-hidden rounded-lg bg-n-alpha-1"
            >
              <img
                v-if="option.url"
                :src="option.url"
                class="size-full object-contain"
              />
              <Logo v-else class="size-6" />
            </span>
            <span class="text-sm text-n-slate-12">{{ option.label }}</span>
          </button>
        </div>
      </fieldset>
    </div>
  </SectionLayout>
</template>

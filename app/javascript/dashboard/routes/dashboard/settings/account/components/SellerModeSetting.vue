<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import SectionLayout from './SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';

const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();
const isEnabled = ref(true);

watch(
  currentAccount,
  () => {
    isEnabled.value = currentAccount.value?.settings?.seller_mode !== false;
  },
  { deep: true, immediate: true }
);

const toggleSellerMode = async () => {
  try {
    await updateAccount({ seller_mode: isEnabled.value });
    useAlert(t('GENERAL_SETTINGS.FORM.SELLER_MODE.API.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.SELLER_MODE.API.ERROR'));
  }
};
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.SELLER_MODE.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.SELLER_MODE.NOTE')"
    with-border
  >
    <template #headerActions>
      <div class="flex justify-end">
        <Switch v-model="isEnabled" @change="toggleSellerMode" />
      </div>
    </template>
  </SectionLayout>
</template>

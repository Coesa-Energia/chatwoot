<script setup>
import { watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useCampaignAnalytics } from 'dashboard/composables/useCampaignAnalytics';
import { useAccount } from 'dashboard/composables/useAccount';
import WhatsAppCampaignAnalyticsContent from './WhatsAppCampaignAnalyticsContent.vue';

const router = useRouter();
const route = useRoute();
const { accountScopedRoute, currentAccount } = useAccount();
const { canViewAnalytics } = useCampaignAnalytics();
watch(
  [() => route.name, currentAccount, canViewAnalytics],
  ([routeName, account, canView]) => {
    if (
      routeName === 'campaigns_whatsapp_analytics' &&
      account.id &&
      !canView
    ) {
      router.replace(accountScopedRoute('campaigns_whatsapp_index'));
    }
  },
  { immediate: true }
);
</script>

<template>
  <WhatsAppCampaignAnalyticsContent v-if="canViewAnalytics" />
</template>

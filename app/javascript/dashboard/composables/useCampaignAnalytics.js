import { computed } from 'vue';
import { useConfig } from 'dashboard/composables/useConfig';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

// COESA FORK: instalação própria 100% free, analytics sempre liberado.
export function useCampaignAnalytics() {
  const { isEnterprise } = useConfig();
  const { isFeatureFlagEnabled } = usePolicy();
  const showPaywall = computed(() => false);
  const canViewAnalytics = computed(
    () => isEnterprise && isFeatureFlagEnabled(FEATURE_FLAGS.CAMPAIGN_ANALYTICS)
  );

  return { canViewAnalytics, showPaywall };
}

import { computed } from 'vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';

/**
 * "Modo Vendedor": agents get a simplified dashboard focused on WhatsApp sales
 * (no snooze/pending/priority/SLA, macros, mentions; Captain and help center read-only parts only).
 * Administrators always see everything. On by default; an administrator can turn
 * it off per account (Settings > Account, settings.seller_mode = false).
 * Everything hidden by this switch is listed in docs/FUNCOES_ESCONDIDAS.md.
 */
// Chat list status/sort options offered in seller mode (the rest stay admin-only).
export const SELLER_MODE_STATUS_FILTERS = ['open', 'resolved', 'all'];
export const SELLER_MODE_SORT_OPTIONS = [
  'last_activity_at_desc',
  'last_activity_at_asc',
];

export function useSellerMode() {
  const { isAdmin } = useAdmin();
  const { currentAccount } = useAccount();

  const isSellerModeEnabledOnAccount = computed(
    () => currentAccount.value?.settings?.seller_mode !== false
  );
  const isSellerMode = computed(
    () => !isAdmin.value && isSellerModeEnabledOnAccount.value
  );

  return { isSellerMode, isSellerModeEnabledOnAccount };
}

import { computed } from 'vue';
import { useAccount } from './useAccount';
import { useAdmin } from './useAdmin';

export function usePaymentStatus() {
  const { accountId, isOnChatwootCloud } = useAccount();
  const { isAdmin: canManagePayment } = useAdmin();

  // COESA FORK: this installation has no subscriptions or paid plans, so an
  // account can never be past due (Cloud or self-hosted licence).
  const isPastDue = computed(() => false);

  return { accountId, isPastDue, canManagePayment, isOnChatwootCloud };
}

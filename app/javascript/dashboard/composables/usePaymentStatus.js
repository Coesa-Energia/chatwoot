import { computed } from 'vue';
import { useAccount } from './useAccount';
import { useAdmin } from './useAdmin';

export function usePaymentStatus() {
  const { accountId } = useAccount();
  const { isAdmin: canManagePayment } = useAdmin();

  // This installation has no subscriptions or paid plans, so an account can
  // never be past due.
  const isPastDue = computed(() => false);

  return { accountId, isPastDue, canManagePayment };
}

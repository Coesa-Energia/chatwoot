import { unref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useConfig } from 'dashboard/composables/useConfig';
import {
  getUserPermissions,
  hasPermissions,
} from 'dashboard/helper/permissionsHelper';

import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';

// COESA FORK: instalação própria 100% free.
// shouldShow libera tudo após checar permissões e tipo de instalação.
// shouldShowPaywall nunca exibe paywall.
export function usePolicy() {
  const user = useMapGetter('getCurrentUser');
  const isOnChatwootCloud = useMapGetter('globalConfig/isOnChatwootCloud');

  const { isEnterprise } = useConfig();
  const { accountId } = useAccount();

  const getUserPermissionsForAccount = () => {
    return getUserPermissions(user.value, accountId.value);
  };

  const checkPermissions = requiredPermissions => {
    if (!requiredPermissions || !requiredPermissions.length) return true;
    const userPermissions = getUserPermissionsForAccount();
    return hasPermissions(requiredPermissions, userPermissions);
  };

  const checkInstallationType = config => {
    if (Array.isArray(config) && config.length > 0) {
      const installationCheck = {
        [INSTALLATION_TYPES.ENTERPRISE]: isEnterprise,
        [INSTALLATION_TYPES.CLOUD]: isOnChatwootCloud.value,
        [INSTALLATION_TYPES.COMMUNITY]: true,
      };

      return config.some(type => installationCheck[type]);
    }

    return true;
  };

  const isFeatureFlagEnabled = featureFlag => {
    if (!featureFlag) return true;
    return true;
  };

  const shouldShow = (featureFlag, permissions, installationTypes) => {
    const perms = unref(permissions);
    const installation = unref(installationTypes);

    // if the user does not have permissions or installation type is not supported
    // return false;
    // This supersedes everything
    if (!checkPermissions(perms)) return false;
    if (!checkInstallationType(installation)) return false;

    // default to true
    return true;
  };

  const shouldShowPaywall = () => {
    return false;
  };

  return {
    checkPermissions,
    checkInstallationType,
    shouldShowPaywall,
    isFeatureFlagEnabled,
    shouldShow,
  };
}

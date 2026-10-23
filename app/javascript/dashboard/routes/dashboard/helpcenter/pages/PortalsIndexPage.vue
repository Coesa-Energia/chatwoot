<script setup>
import { computed, nextTick, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { PORTAL_PERMISSIONS } from 'dashboard/constants/permissions';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const store = useStore();
const router = useRouter();
const { uiSettings } = useUISettings();
const route = useRoute();
const { checkPermissions } = usePolicy();
const canManageKnowledgeBase = computed(() =>
  checkPermissions(['administrator', PORTAL_PERMISSIONS])
);

const portals = computed(() => store.getters['portals/allPortals']);

const isPortalPresent = portalSlug => {
  return !!portals.value.find(portal => portal.slug === portalSlug);
};

const routeToView = (name, params) => {
  router.replace({ name, params, replace: true });
};

const generateRouterParams = () => {
  const {
    last_active_portal_slug: lastActivePortalSlug,
    last_active_locale_code: lastActiveLocaleCode,
  } = uiSettings.value || {};
  if (isPortalPresent(lastActivePortalSlug)) {
    return {
      portalSlug: lastActivePortalSlug,
      locale: lastActiveLocaleCode,
    };
  }

  if (portals.value.length > 0) {
    const { slug: portalSlug, meta: { default_locale: locale } = {} } =
      portals.value[0];
    return { portalSlug, locale };
  }

  return null;
};

const routeToLastActivePortal = () => {
  const params = generateRouterParams();
  const { navigationPath } = route.params;
  const validRoutes = canManageKnowledgeBase.value
    ? [
        'portals_articles_index',
        'portals_categories_index',
        'portals_locales_index',
        'portals_settings_index',
      ]
    : ['portals_articles_index'];

  const navigateTo = validRoutes.includes(navigationPath)
    ? navigationPath
    : 'portals_articles_index';
  if (params) {
    return routeToView(navigateTo, params);
  }
  // Readers can't create a portal; with none to read, send them home.
  if (!canManageKnowledgeBase.value) {
    return router.replace({
      name: 'home',
      params: { accountId: route.params.accountId },
    });
  }
  return routeToView('portals_new', {});
};

const performRouting = async () => {
  await store.dispatch('portals/index');
  nextTick(() => routeToLastActivePortal());
};

onMounted(() => performRouting());
</script>

<template>
  <div
    class="flex items-center justify-center w-full bg-n-surface-1 text-n-slate-11"
  >
    <Spinner />
  </div>
</template>

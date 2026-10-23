import { inject, provide, ref, computed } from 'vue';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useRouter } from 'vue-router';
import { useUISettings } from 'dashboard/composables/useUISettings';

const SidebarControl = Symbol('SidebarControl');

const MIN_WIDTH = 56;
const MAX_WIDTH = 320;
// Open width: 60% of the maximum. It is also the smallest the open sidebar can be dragged to; the only way to
// make it narrower than this is to collapse it with the button in the header (icons only, MIN_WIDTH).
const OPEN_WIDTH = Math.round(MAX_WIDTH * 0.6);
// Widths saved by the old drag-to-resize handle: anything below this was a collapsed sidebar.
const LEGACY_COLLAPSED_THRESHOLD = 160;

// Shared state for active popover (only one can be open at a time)
const activePopover = ref(null);
let globalCloseTimeout = null;

// Shared by the sidebar and the header button that toggles it.
const isSidebarOpen = ref(null);
const openWidth = ref(OPEN_WIDTH);

const clampOpenWidth = width =>
  Math.max(
    OPEN_WIDTH,
    Math.min(MAX_WIDTH, Math.round(Number(width) || OPEN_WIDTH))
  );

export function useSidebarState() {
  const { uiSettings, updateUISettings } = useUISettings();

  if (isSidebarOpen.value === null) {
    const {
      sidebar_width: savedWidth,
      sidebar_collapsed: savedCollapsed,
      sidebar_open_width: savedOpenWidth,
    } = uiSettings.value;
    const legacyCollapsed =
      savedWidth !== undefined && savedWidth < LEGACY_COLLAPSED_THRESHOLD;
    isSidebarOpen.value =
      savedCollapsed === undefined ? !legacyCollapsed : !savedCollapsed;
    openWidth.value = clampOpenWidth(
      savedOpenWidth ?? (legacyCollapsed ? OPEN_WIDTH : savedWidth)
    );
  }

  const sidebarWidth = computed(() =>
    isSidebarOpen.value ? openWidth.value : MIN_WIDTH
  );
  const isCollapsed = computed(() => !isSidebarOpen.value);

  const persist = () =>
    updateUISettings({
      sidebar_collapsed: !isSidebarOpen.value,
      sidebar_open_width: openWidth.value,
    });

  const toggleSidebar = () => {
    isSidebarOpen.value = !isSidebarOpen.value;
    persist();
  };

  // While dragging: follows the pointer but never gets narrower than OPEN_WIDTH nor wider than MAX_WIDTH.
  const setOpenWidth = width => {
    openWidth.value = clampOpenWidth(width);
  };
  const saveOpenWidth = persist;
  const resetOpenWidth = () => {
    openWidth.value = OPEN_WIDTH;
    persist();
  };

  return {
    sidebarWidth,
    isCollapsed,
    isSidebarOpen,
    toggleSidebar,
    setOpenWidth,
    saveOpenWidth,
    resetOpenWidth,
    MIN_WIDTH,
    OPEN_WIDTH,
    MAX_WIDTH,
  };
}

export function usePopoverState() {
  const setActivePopover = name => {
    clearTimeout(globalCloseTimeout);
    activePopover.value = name;
  };

  const closeActivePopover = () => {
    activePopover.value = null;
  };

  const scheduleClose = (delay = 150) => {
    clearTimeout(globalCloseTimeout);
    globalCloseTimeout = setTimeout(() => {
      closeActivePopover();
    }, delay);
  };

  const cancelClose = () => {
    clearTimeout(globalCloseTimeout);
  };

  return {
    activePopover,
    setActivePopover,
    closeActivePopover,
    scheduleClose,
    cancelClose,
  };
}

export function useSidebarContext() {
  const context = inject(SidebarControl, null);
  if (context === null) {
    throw new Error(`Component is missing a parent <Sidebar /> component.`);
  }

  const router = useRouter();
  const { shouldShow } = usePolicy();

  const resolvePath = to => {
    if (to) return router.resolve(to)?.path || '/';
    return '/';
  };

  // Helper to find route definition by name without resolving
  const findRouteByName = name => {
    const routes = router.getRoutes();
    return routes.find(route => route.name === name);
  };

  const resolvePermissions = to => {
    if (!to) return [];

    // If navigationPath param exists, get the target route definition
    if (to.params?.navigationPath) {
      const targetRoute = findRouteByName(to.params.navigationPath);
      return targetRoute?.meta?.permissions ?? [];
    }

    return router.resolve(to)?.meta?.permissions ?? [];
  };

  const resolveFeatureFlag = to => {
    if (!to) return '';

    // If navigationPath param exists, get the target route definition
    if (to.params?.navigationPath) {
      const targetRoute = findRouteByName(to.params.navigationPath);
      return targetRoute?.meta?.featureFlag || '';
    }

    return router.resolve(to)?.meta?.featureFlag || '';
  };

  const resolveInstallationType = to => {
    if (!to) return [];

    // If navigationPath param exists, get the target route definition
    if (to.params?.navigationPath) {
      const targetRoute = findRouteByName(to.params.navigationPath);
      return targetRoute?.meta?.installationTypes || [];
    }

    return router.resolve(to)?.meta?.installationTypes || [];
  };

  const isAllowed = to => {
    const permissions = resolvePermissions(to);
    const featureFlag = resolveFeatureFlag(to);
    const installationType = resolveInstallationType(to);

    return shouldShow(featureFlag, permissions, installationType);
  };

  return {
    ...context,
    resolvePath,
    resolvePermissions,
    resolveFeatureFlag,
    isAllowed,
  };
}

export function provideSidebarContext(context) {
  provide(SidebarControl, context);
}

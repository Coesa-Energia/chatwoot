<script setup>
import { useI18n } from 'vue-i18n';
import { useSidebarState } from './provider';

import Button from 'dashboard/components-next/button/Button.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';

const { t } = useI18n();
const { isSidebarOpen, toggleSidebar } = useSidebarState();
</script>

<template>
  <header
    class="flex flex-shrink-0 gap-3 justify-end items-center px-4 h-12 border-b bg-n-background border-n-weak"
  >
    <!-- Desktop only: on mobile the menu opens from its own floating button. -->
    <Button
      v-tooltip.bottom="t('SIDEBAR.TOGGLE_MENU')"
      :aria-label="t('SIDEBAR.TOGGLE_MENU')"
      :aria-expanded="isSidebarOpen"
      icon="i-lucide-menu"
      color="slate"
      size="md"
      data-testid="sidebar-toggle"
      class="!hidden md:!inline-flex !h-9 !w-9 !text-n-slate-11 ltr:me-auto rtl:ms-auto"
      @click="toggleSidebar"
    />
    <RouterLink
      :to="{ name: 'search' }"
      class="flex gap-2 items-center px-3 h-9 w-72 max-w-full text-sm rounded-lg outline outline-1 outline-n-weak bg-n-button-color transition-colors duration-150 ease-out hover:bg-n-alpha-2 dark:hover:bg-n-slate-9/30 focus-visible:outline-2 focus-visible:outline-n-brand"
    >
      <span class="flex-shrink-0 i-lucide-search size-4 text-n-slate-11" />
      <span class="flex-grow truncate text-start text-n-slate-11">
        {{ t('COMBOBOX.SEARCH_PLACEHOLDER') }}
      </span>
    </RouterLink>
    <ComposeConversation align="end">
      <template #trigger="{ isOpen }">
        <Button
          v-tooltip.bottom="t('SIDEBAR.NEW_CONVERSATION')"
          :aria-label="t('SIDEBAR.NEW_CONVERSATION')"
          icon="i-lucide-pen-line"
          color="slate"
          size="md"
          class="!h-9 !w-9 !outline-n-weak !text-n-slate-11 dark:hover:!bg-n-slate-9/30"
          :class="{ '!bg-n-alpha-2 dark:!bg-n-slate-9/30': isOpen }"
        />
      </template>
    </ComposeConversation>
  </header>
</template>

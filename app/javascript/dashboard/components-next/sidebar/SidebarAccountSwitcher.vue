<script setup>
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import ButtonNext from 'next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';
import AccountLogo from './AccountLogo.vue';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
} from 'next/dropdown-menu/base';

defineProps({
  isCollapsed: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['showCreateAccountModal']);

const { t } = useI18n();
const { accountId, currentAccount } = useAccount();
const currentUser = useMapGetter('getCurrentUser');
const globalConfig = useMapGetter('globalConfig/get');

const userAccounts = useMapGetter('getUserAccounts');

const brandDisplay = computed(
  () => currentAccount.value?.brand_display || 'logo_name'
);
const showLogo = computed(() => brandDisplay.value !== 'name');
// A logo shown alone gets the most room; next to the name it stays smaller.
const logoHeight = computed(
  () =>
    ({ logo: 'h-12', logo_name: 'h-9', logo_name_inline: 'h-8' })[
      brandDisplay.value
    ] || 'h-8'
);
const showName = computed(() => brandDisplay.value !== 'logo');

const showAccountSwitcher = computed(
  () => userAccounts.value.length > 1 && currentAccount.value.name
);

const sortedCurrentUserAccounts = computed(() => {
  return [...(currentUser.value.accounts || [])].sort((a, b) =>
    a.name.localeCompare(b.name)
  );
});

const onChangeAccount = newId => {
  const accountUrl = `/app/accounts/${newId}/dashboard`;
  window.location.href = accountUrl;
};

const emitNewAccount = () => {
  emit('showCreateAccountModal');
};
</script>

<template>
  <DropdownContainer>
    <template #trigger="{ toggle, isOpen }">
      <!-- Collapsed view: Logo trigger -->
      <button
        v-if="isCollapsed"
        class="grid flex-shrink-0 place-content-center p-2 rounded-lg cursor-pointer hover:bg-n-alpha-1 focus-visible:outline focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-n-brand"
        :class="{ 'bg-n-alpha-1': isOpen }"
        :title="currentAccount.name"
        @click="toggle"
      >
        <AccountLogo
          height="h-7"
          max-width="max-w-[2.25rem]"
          variant="collapsed"
        />
      </button>
      <!-- Expanded view: logo and/or name, as chosen in Settings > Account -->
      <button
        v-else
        id="sidebar-account-switcher"
        :data-account-id="accountId"
        :data-brand-display="brandDisplay"
        :title="currentAccount.name"
        aria-haspopup="listbox"
        aria-controls="account-options"
        class="relative flex items-center justify-center w-full rounded-lg py-1.5 focus-visible:outline focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-n-brand"
        :class="[
          showAccountSwitcher ? 'px-7' : 'px-2',
          isOpen && 'bg-n-alpha-1',
          showAccountSwitcher
            ? 'hover:bg-n-alpha-1 cursor-pointer'
            : 'cursor-default',
        ]"
        @click="() => showAccountSwitcher && toggle()"
      >
        <span
          class="flex min-w-0 max-w-full gap-1.5"
          :class="
            brandDisplay === 'logo_name'
              ? 'flex-col items-center'
              : 'flex-row items-center'
          "
        >
          <AccountLogo
            v-if="showLogo"
            :variant="brandDisplay === 'logo' ? 'main' : 'text'"
            :height="logoHeight"
            :max-width="
              brandDisplay === 'logo_name_inline' ? 'max-w-[5rem]' : undefined
            "
          />
          <span
            v-if="showName"
            class="max-w-full text-center text-sm font-semibold leading-5 text-n-slate-12 truncate"
            aria-live="polite"
          >
            {{ currentAccount.name }}
          </span>
        </span>

        <span
          v-if="showAccountSwitcher"
          aria-hidden="true"
          class="i-lucide-chevron-down absolute top-1/2 -translate-y-1/2 ltr:right-2 rtl:left-2 size-4 text-n-slate-11"
        />
      </button>
    </template>
    <DropdownBody
      v-if="showAccountSwitcher || isCollapsed"
      class="min-w-80 z-50"
    >
      <DropdownSection :title="t('SIDEBAR_ITEMS.SWITCH_ACCOUNT')">
        <DropdownItem
          v-for="account in sortedCurrentUserAccounts"
          :id="`account-${account.id}`"
          :key="account.id"
          class="cursor-pointer"
          @click="onChangeAccount(account.id)"
        >
          <template #label>
            <div
              :for="account.name"
              class="text-left rtl:text-right flex gap-2 items-center"
            >
              <span
                class="text-n-slate-12 max-w-36 truncate min-w-0"
                :title="account.name"
              >
                {{ account.name }}
              </span>
              <div class="flex-shrink-0 w-px h-3 bg-n-strong" />
              <span
                class="text-n-slate-11 max-w-24 truncate capitalize"
                :title="account.name"
              >
                {{
                  account.custom_role_id
                    ? account.custom_role.name
                    : account.role
                }}
              </span>
            </div>
            <Icon
              v-show="account.id === accountId"
              icon="i-lucide-check"
              class="text-n-brand size-5"
            />
          </template>
        </DropdownItem>
      </DropdownSection>
      <DropdownItem v-if="globalConfig.createNewAccountFromDashboard">
        <ButtonNext
          color="slate"
          variant="faded"
          class="w-full"
          size="sm"
          @click="emitNewAccount"
        >
          {{ t('CREATE_ACCOUNT.NEW_ACCOUNT') }}
        </ButtonNext>
      </DropdownItem>
    </DropdownBody>
  </DropdownContainer>
</template>

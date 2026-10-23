<script setup>
import BillingCard from './components/BillingCard.vue';
import DetailItem from './components/DetailItem.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="$t('BILLING_SETTINGS.TITLE')"
        :description="$t('BILLING_SETTINGS.DESCRIPTION')"
      />
    </template>
    <template #body>
      <section class="grid gap-4">
        <BillingCard
          :title="$t('BILLING_SETTINGS.FREE_PLAN.TITLE')"
          :description="$t('BILLING_SETTINGS.FREE_PLAN.DESCRIPTION')"
        >
          <div
            class="grid grid-cols-1 gap-2 divide-x divide-n-weak sm:grid-cols-3"
          >
            <DetailItem
              :label="$t('BILLING_SETTINGS.FREE_PLAN.PLAN')"
              :value="$t('BILLING_SETTINGS.FREE_PLAN.PLAN_VALUE')"
            />
            <DetailItem
              :label="$t('BILLING_SETTINGS.FREE_PLAN.SEATS')"
              :value="$t('BILLING_SETTINGS.FREE_PLAN.SEATS_VALUE')"
            />
            <DetailItem
              :label="$t('BILLING_SETTINGS.FREE_PLAN.FEATURES')"
              :value="$t('BILLING_SETTINGS.FREE_PLAN.FEATURES_VALUE')"
            />
          </div>
        </BillingCard>
      </section>
    </template>
  </SettingsLayout>
</template>

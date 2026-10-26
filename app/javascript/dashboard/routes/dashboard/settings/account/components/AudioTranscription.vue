<script setup>
import { ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import AudioTranscriptionUsagesAPI from 'dashboard/api/audioTranscriptionUsages';
import SectionLayout from './SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';

const { t, locale } = useI18n();
const isEnabled = ref(false);
const usage = ref(null);

const { currentAccount, updateAccount } = useAccount();

watch(
  currentAccount,
  () => {
    const { audio_transcriptions } = currentAccount.value?.settings || {};
    isEnabled.value = !!audio_transcriptions;
  },
  { deep: true, immediate: true }
);

const updateAccountSettings = async settings => {
  try {
    await updateAccount(settings);
    useAlert(t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.API.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.API.ERROR'));
  }
};

const toggleAudioTranscription = async () => {
  return updateAccountSettings({
    audio_transcriptions: isEnabled.value,
  });
};

// COESA: monthly spend report (one row per request to the transcription server).
onMounted(async () => {
  try {
    const { data } = await AudioTranscriptionUsagesAPI.get();
    usage.value = data;
  } catch {
    usage.value = null;
  }
});

const formatMonth = month => {
  const [year, monthIndex] = month.split('-').map(Number);
  return new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
    month: 'short',
    year: 'numeric',
  }).format(new Date(year, monthIndex - 1, 1));
};

const formatMinutes = seconds =>
  t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.USAGE.MINUTES', {
    minutes: (seconds / 60).toFixed(seconds < 600 ? 1 : 0),
  });

const estimatedCost = row => {
  const { cost_per_minute: perMinute, monthly_fixed_cost: fixed } = usage.value;
  if (perMinute == null && fixed == null) return '—';
  const total = (row.audio_seconds / 60) * (perMinute || 0) + (fixed || 0);
  return `US$ ${total.toFixed(2)}`;
};
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.NOTE')"
    with-border
  >
    <template #headerActions>
      <div class="flex justify-end">
        <Switch v-model="isEnabled" @change="toggleAudioTranscription" />
      </div>
    </template>
    <div v-if="usage" class="flex flex-col gap-2">
      <h5 class="text-sm font-medium text-n-slate-12">
        {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.USAGE.TITLE') }}
      </h5>
      <p v-if="!usage.months.length" class="text-sm text-n-slate-11">
        {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.USAGE.EMPTY') }}
      </p>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm tabular-nums">
          <thead>
            <tr class="text-left text-n-slate-11">
              <th class="py-1.5 pr-4 font-normal">
                {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.USAGE.MONTH') }}
              </th>
              <th class="py-1.5 pr-4 font-normal text-right">
                {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.USAGE.CALLS') }}
              </th>
              <th class="py-1.5 pr-4 font-normal text-right">
                {{
                  t(
                    'GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.USAGE.VOICE_NOTES'
                  )
                }}
              </th>
              <th class="py-1.5 pr-4 font-normal text-right">
                {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.USAGE.AUDIO') }}
              </th>
              <th class="py-1.5 pr-4 font-normal text-right">
                {{
                  t(
                    'GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.USAGE.PROCESSING'
                  )
                }}
              </th>
              <th class="py-1.5 font-normal text-right">
                {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.USAGE.COST') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in usage.months"
              :key="row.month"
              class="border-t border-n-weak"
            >
              <td class="py-1.5 pr-4 capitalize">
                {{ formatMonth(row.month) }}
              </td>
              <td class="py-1.5 pr-4 text-right">{{ row.calls }}</td>
              <td class="py-1.5 pr-4 text-right">{{ row.voice_notes }}</td>
              <td class="py-1.5 pr-4 text-right">
                {{ formatMinutes(row.audio_seconds) }}
              </td>
              <td class="py-1.5 pr-4 text-right">
                {{ formatMinutes(row.processing_seconds) }}
              </td>
              <td class="py-1.5 text-right">{{ estimatedCost(row) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p class="text-xs text-n-slate-11">
        {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.USAGE.COST_NOTE') }}
      </p>
    </div>
  </SectionLayout>
</template>

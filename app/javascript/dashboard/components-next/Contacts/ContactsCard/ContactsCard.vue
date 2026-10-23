<script setup>
import { computed } from 'vue';
import { dynamicTime } from 'shared/helpers/timeHelper';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import countries from 'shared/constants/countries';

const props = defineProps({
  id: { type: Number, required: true },
  name: { type: String, default: '' },
  email: { type: String, default: '' },
  additionalAttributes: { type: Object, default: () => ({}) },
  phoneNumber: { type: String, default: '' },
  thumbnail: { type: String, default: '' },
  availabilityStatus: { type: String, default: null },
  lastActivityAt: { type: Number, default: null },
  selectable: { type: Boolean, default: false },
  isSelected: { type: Boolean, default: false },
});

const emit = defineEmits(['showContact', 'select', 'avatarHover']);

const location = computed(() => {
  const { country, countryCode, city } = props.additionalAttributes || {};
  const activeCountry = countries.find(
    item => item.id === country || item.id === countryCode
  );
  return [city, activeCountry?.name].filter(Boolean).join(', ');
});

const subtitle = computed(() =>
  [props.additionalAttributes?.companyName, location.value]
    .filter(Boolean)
    .join(' · ')
);

const lastActivity = computed(() =>
  props.lastActivityAt ? dynamicTime(props.lastActivityAt) : ''
);

const openContact = () => emit('showContact', props.id);
</script>

<template>
  <div
    role="link"
    tabindex="0"
    class="flex items-center gap-3 px-4 py-2.5 cursor-pointer transition-colors duration-150 motion-reduce:transition-none hover:bg-n-alpha-1 focus-visible:outline focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-n-brand"
    :class="{ '!bg-n-alpha-2': isSelected }"
    @click="openContact"
    @keydown.enter.self="openContact"
  >
    <div
      class="relative shrink-0"
      @mouseenter="emit('avatarHover', true)"
      @mouseleave="emit('avatarHover', false)"
    >
      <Avatar
        :name="name"
        :src="thumbnail"
        :size="32"
        :status="availabilityStatus"
        hide-offline-status
      >
        <template v-if="selectable" #overlay="{ size }">
          <label
            class="flex items-center justify-center rounded-full cursor-pointer absolute inset-0 z-10 backdrop-blur-[2px] border border-n-weak"
            :style="{ width: `${size}px`, height: `${size}px` }"
            @click.stop
          >
            <Checkbox
              :model-value="isSelected"
              @change="event => emit('select', event.target.checked)"
            />
          </label>
        </template>
      </Avatar>
    </div>
    <div
      class="grid flex-1 min-w-0 items-center gap-x-4 md:grid-cols-[minmax(0,2fr)_minmax(0,1.2fr)_minmax(0,1.6fr)_7rem]"
    >
      <div class="min-w-0">
        <p class="text-sm font-medium truncate text-n-slate-12">
          {{ name || phoneNumber || email }}
        </p>
        <p v-if="subtitle" class="text-xs truncate text-n-slate-11">
          {{ subtitle }}
        </p>
        <p class="text-xs truncate md:hidden text-n-slate-11">
          {{ [phoneNumber, email].filter(Boolean).join(' · ') }}
        </p>
      </div>
      <span class="hidden text-sm truncate md:block text-n-slate-11">
        {{ phoneNumber || '—' }}
      </span>
      <span
        class="hidden text-sm truncate md:block text-n-slate-11"
        :title="email"
      >
        {{ email || '—' }}
      </span>
      <span class="hidden text-xs truncate md:block text-end text-n-slate-11">
        {{ lastActivity }}
      </span>
    </div>
    <span
      class="i-lucide-chevron-right size-4 shrink-0 text-n-slate-10 rtl:rotate-180"
      aria-hidden="true"
    />
  </div>
</template>

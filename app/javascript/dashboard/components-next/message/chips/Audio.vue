<script setup>
import {
  computed,
  onBeforeUnmount,
  onMounted,
  useTemplateRef,
  ref,
  watch,
  getCurrentInstance,
} from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';
import { timeStampAppendedURL } from 'dashboard/helper/URLHelper';
import { downloadFile } from '@chatwoot/utils';
import { useEmitter } from 'dashboard/composables/emitter';
import { emitter } from 'shared/helpers/mitt';
import { useAudioWaveform } from 'dashboard/composables/useAudioWaveform';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import AudioTranscriptionUsagesAPI from 'dashboard/api/audioTranscriptionUsages';
import { useOptionalMessageContext } from '../provider.js';

const { attachment, allowTranscribe } = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
  showTranscribedText: {
    type: Boolean,
    default: true,
  },
  // Call recordings are transcribed automatically, so their bubble hides the button.
  allowTranscribe: {
    type: Boolean,
    default: true,
  },
});

defineOptions({
  inheritAttrs: false,
});

const timeStampURL = computed(() => {
  return timeStampAppendedURL(attachment.dataUrl);
});

// COESA: the transcript starts collapsed behind a chevron; voice notes are transcribed on request.
const { t } = useI18n();
const { currentAccount } = useAccount();
const messageContext = useOptionalMessageContext();
const TRANSCRIBE_WAIT_MS = 3 * 60 * 1000;

const transcript = computed(() => attachment.transcribedText || '');
const isTranscriptExpanded = ref(false);
const isTranscribing = ref(false);
let transcribeTimer;

const canTranscribe = computed(
  () =>
    allowTranscribe &&
    !transcript.value &&
    !!attachment.id &&
    !!messageContext?.conversationId?.value &&
    !!currentAccount.value?.settings?.audio_transcriptions
);

watch(transcript, text => {
  if (!text || !isTranscribing.value) return;
  isTranscribing.value = false;
  isTranscriptExpanded.value = true;
  clearTimeout(transcribeTimer);
});

const transcribe = async () => {
  if (isTranscribing.value) return;
  isTranscribing.value = true;
  try {
    await AudioTranscriptionUsagesAPI.transcribeMessage({
      conversationId: messageContext.conversationId.value,
      messageId: attachment.messageId || messageContext.id.value,
    });
    // The transcript arrives with the message.updated event; give up waiting after a while.
    transcribeTimer = setTimeout(() => {
      isTranscribing.value = false;
    }, TRANSCRIBE_WAIT_MS);
  } catch (error) {
    isTranscribing.value = false;
    useAlert(
      error?.response?.data?.error ||
        t('CONVERSATION.VOICE_CALL.TRANSCRIBE_ERROR')
    );
  }
};

const audioPlayer = useTemplateRef('audioPlayer');

const isPlaying = ref(false);
const isMuted = ref(false);
const currentTime = ref(0);
const duration = ref(0);
const playbackSpeed = ref(1);

const { uid } = getCurrentInstance();

// MediaRecorder-produced WebM/Opus blobs lack a Duration header → <audio>.duration
// resolves to Infinity until we seek past the end, which forces the engine to
// scan the file and compute the real length. Safe no-op for files with a real
// duration already (mp3/m4a/etc).
const resolveStreamingDuration = () => {
  const el = audioPlayer.value;
  if (!el) return;
  const onTimeUpdate = () => {
    el.removeEventListener('timeupdate', onTimeUpdate);
    el.currentTime = 0;
    duration.value = el.duration;
  };
  el.addEventListener('timeupdate', onTimeUpdate);
  try {
    el.currentTime = Number.MAX_SAFE_INTEGER;
  } catch {
    el.removeEventListener('timeupdate', onTimeUpdate);
  }
};

const onLoadedMetadata = () => {
  const d = audioPlayer.value?.duration;
  if (!Number.isFinite(d)) {
    resolveStreamingDuration();
    return;
  }
  duration.value = d;
};

const playbackSpeedLabel = computed(() => {
  return `${playbackSpeed.value}x`;
});

// There maybe a chance that the audioPlayer ref is not available
// When the onLoadMetadata is called, so we need to set the duration
// value when the component is mounted
const { peaks, load: loadWaveform } = useAudioWaveform();
let observer;
onBeforeUnmount(() => {
  observer?.disconnect();
  clearTimeout(transcribeTimer);
});
const waveform = useTemplateRef('waveform');
const playedRatio = computed(() =>
  duration.value ? Math.min(1, currentTime.value / duration.value) : 0
);

onMounted(() => {
  const d = audioPlayer.value?.duration;
  if (Number.isFinite(d)) duration.value = d;
  audioPlayer.value.playbackRate = playbackSpeed.value;

  // Decode the audio only once the bubble is on screen, not for the whole history.
  if (typeof IntersectionObserver === 'undefined' || !waveform.value) return;
  observer = new IntersectionObserver(entries => {
    if (!entries.some(entry => entry.isIntersecting)) return;
    observer.disconnect();
    loadWaveform(attachment.dataUrl);
  });
  observer.observe(waveform.value);
});

// Listen for global audio play events and pause if it's not this audio
useEmitter('pause_playing_audio', currentPlayingId => {
  if (currentPlayingId !== uid && isPlaying.value) {
    try {
      audioPlayer.value.pause();
    } catch {
      /* ignore pause errors */
    }
    isPlaying.value = false;
  }
});

const formatTime = time => {
  if (!time || Number.isNaN(time)) return '00:00';
  const minutes = Math.floor(time / 60);
  const seconds = Math.floor(time % 60);
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
};

const toggleMute = () => {
  audioPlayer.value.muted = !audioPlayer.value.muted;
  isMuted.value = audioPlayer.value.muted;
};

const onTimeUpdate = () => {
  currentTime.value = audioPlayer.value?.currentTime;
};

const seek = event => {
  const time = Number(event.target.value);
  audioPlayer.value.currentTime = time;
  currentTime.value = time;
};

const seekFromWaveform = event => {
  const { left, width } = event.currentTarget.getBoundingClientRect();
  if (!width || !duration.value) return;
  const ratio = Math.min(1, Math.max(0, (event.clientX - left) / width));
  const time = ratio * duration.value;
  audioPlayer.value.currentTime = time;
  currentTime.value = time;
};

const playOrPause = () => {
  if (isPlaying.value) {
    audioPlayer.value.pause();
    isPlaying.value = false;
  } else {
    // Emit event to pause all other audio
    emitter.emit('pause_playing_audio', uid);
    audioPlayer.value.play();
    isPlaying.value = true;
  }
};

const onEnd = () => {
  isPlaying.value = false;
  currentTime.value = 0;
  playbackSpeed.value = 1;
  audioPlayer.value.playbackRate = 1;
};

const changePlaybackSpeed = () => {
  const speeds = [1, 1.5, 2];
  const currentIndex = speeds.indexOf(playbackSpeed.value);
  const nextIndex = (currentIndex + 1) % speeds.length;
  playbackSpeed.value = speeds[nextIndex];
  audioPlayer.value.playbackRate = playbackSpeed.value;
};

const downloadAudio = async () => {
  const { fileType, dataUrl, extension } = attachment;
  downloadFile({ url: dataUrl, type: fileType, extension });
};
</script>

<template>
  <audio
    ref="audioPlayer"
    controls
    class="hidden"
    playsinline
    @loadedmetadata="onLoadedMetadata"
    @timeupdate="onTimeUpdate"
    @ended="onEnd"
  >
    <source :src="timeStampURL" />
  </audio>
  <div
    v-bind="$attrs"
    class="rounded-xl w-full gap-2 p-1.5 bg-n-alpha-white flex flex-col items-center border border-n-container shadow-[0px_2px_8px_0px_rgba(94,94,94,0.06)]"
  >
    <div class="flex gap-1 w-full flex-1 items-center justify-start">
      <button class="p-0 border-0 size-8" @click="playOrPause">
        <Icon
          v-if="isPlaying"
          class="size-8"
          icon="i-teenyicons-pause-small-solid"
        />
        <Icon v-else class="size-8" icon="i-teenyicons-play-small-solid" />
      </button>
      <div class="tabular-nums text-xs">
        {{ formatTime(currentTime) }} / {{ formatTime(duration) }}
      </div>
      <div ref="waveform" class="flex-1 items-center flex px-2">
        <div
          v-if="peaks.length"
          class="flex items-center gap-px w-full h-7 cursor-pointer"
          data-testid="audio-waveform"
          @click="seekFromWaveform"
        >
          <span
            v-for="(peak, index) in peaks"
            :key="index"
            class="flex-1 rounded-full"
            :class="
              index / peaks.length < playedRatio
                ? 'bg-n-brand'
                : 'bg-n-slate-12/30'
            "
            :style="{ height: `${Math.round(peak * 100)}%` }"
          />
        </div>
        <input
          v-else
          type="range"
          min="0"
          :max="duration"
          :value="currentTime"
          class="w-full h-1 bg-n-slate-12/40 rounded-lg appearance-none cursor-pointer accent-current"
          @input="seek"
        />
      </div>
      <button
        class="border-0 w-10 h-6 grid place-content-center bg-n-alpha-2 hover:bg-alpha-3 rounded-2xl"
        @click="changePlaybackSpeed"
      >
        <span class="text-xs text-n-slate-11 font-medium">
          {{ playbackSpeedLabel }}
        </span>
      </button>
      <button
        class="p-0 border-0 size-8 grid place-content-center"
        @click="toggleMute"
      >
        <Icon v-if="isMuted" class="size-4" icon="i-lucide-volume-off" />
        <Icon v-else class="size-4" icon="i-lucide-volume-2" />
      </button>
      <button
        class="p-0 border-0 size-8 grid place-content-center"
        @click="downloadAudio"
      >
        <Icon class="size-4" icon="i-lucide-download" />
      </button>
    </div>

    <div
      v-if="showTranscribedText && (transcript || canTranscribe)"
      class="flex flex-col w-full gap-1"
    >
      <button
        v-if="transcript"
        type="button"
        class="flex items-center gap-1 self-start px-1.5 py-0.5 border-0 bg-transparent text-xs font-medium text-n-slate-11 hover:text-n-slate-12"
        :aria-expanded="isTranscriptExpanded"
        data-testid="audio-transcript-toggle"
        @click="isTranscriptExpanded = !isTranscriptExpanded"
      >
        <Icon
          icon="i-lucide-chevron-right"
          class="size-3.5 transition-transform duration-150"
          :class="{ 'rotate-90': isTranscriptExpanded }"
        />
        {{ $t('CONVERSATION.VOICE_CALL.TRANSCRIPT') }}
      </button>
      <button
        v-else
        type="button"
        class="flex items-center gap-1 self-start px-1.5 py-0.5 border-0 bg-transparent text-xs font-medium text-n-slate-11 hover:text-n-slate-12 disabled:opacity-70"
        :disabled="isTranscribing"
        data-testid="audio-transcribe"
        @click="transcribe"
      >
        <Icon
          :icon="
            isTranscribing ? 'i-lucide-loader-circle' : 'i-lucide-audio-lines'
          "
          class="size-3.5"
          :class="{ 'animate-spin': isTranscribing }"
        />
        {{
          isTranscribing
            ? $t('CONVERSATION.VOICE_CALL.TRANSCRIBING')
            : $t('CONVERSATION.VOICE_CALL.TRANSCRIBE')
        }}
      </button>
      <div
        v-if="transcript && isTranscriptExpanded"
        class="text-n-slate-12 p-3 text-sm bg-n-alpha-1 rounded-lg w-full break-words whitespace-pre-wrap"
        data-testid="audio-transcript"
      >
        {{ transcript }}
      </div>
    </div>
  </div>
</template>

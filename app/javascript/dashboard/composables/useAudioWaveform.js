import { ref } from 'vue';

const BAR_COUNT = 48;
const MAX_BYTES = 5 * 1024 * 1024;
const MIN_HEIGHT = 0.12;

// Cache by URL so scrolling a long chat does not decode the same voice note twice.
const peaksCache = new Map();

/**
 * Reduces decoded samples to `bars` values between MIN_HEIGHT and 1, using the
 * peak of each slice, normalised against the loudest slice.
 */
export const computePeaks = (samples, bars = BAR_COUNT) => {
  if (!samples?.length) return [];
  const size = Math.max(1, Math.floor(samples.length / bars));
  const peaks = [];
  for (let i = 0; i < bars; i += 1) {
    let max = 0;
    const end = Math.min(samples.length, (i + 1) * size);
    for (let j = i * size; j < end; j += 1) {
      const value = Math.abs(samples[j]);
      if (value > max) max = value;
    }
    peaks.push(max);
  }
  const loudest = Math.max(...peaks);
  if (!loudest) return peaks.map(() => MIN_HEIGHT);
  return peaks.map(peak => Math.max(MIN_HEIGHT, peak / loudest));
};

/**
 * Lazily builds the waveform of an audio file. Any failure (CORS, huge file,
 * unsupported codec) leaves `peaks` empty so the caller keeps its plain slider.
 */
export function useAudioWaveform() {
  const peaks = ref([]);

  const load = async url => {
    if (peaksCache.has(url)) {
      peaks.value = peaksCache.get(url);
      return;
    }
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass || !url) return;

    let context;
    try {
      const response = await fetch(url);
      const length = Number(response.headers.get('content-length') || 0);
      if (!response.ok || length > MAX_BYTES) return;

      const buffer = await response.arrayBuffer();
      if (buffer.byteLength > MAX_BYTES) return;

      context = new AudioContextClass();
      const decoded = await context.decodeAudioData(buffer);
      const result = computePeaks(decoded.getChannelData(0));
      peaksCache.set(url, result);
      peaks.value = result;
    } catch {
      peaks.value = [];
    } finally {
      context?.close?.();
    }
  };

  return { peaks, load };
}

import { computePeaks } from '../useAudioWaveform';

describe('computePeaks', () => {
  it('returns nothing for empty audio', () => {
    expect(computePeaks([])).toEqual([]);
    expect(computePeaks(null)).toEqual([]);
  });

  it('returns one value per bar, normalised to the loudest slice', () => {
    const samples = new Float32Array(400);
    samples.fill(0.25, 0, 100);
    samples.fill(-0.5, 100, 200);
    samples.fill(0.5, 200, 300);
    samples.fill(0.1, 300, 400);

    const peaks = computePeaks(samples, 4);

    [0.5, 1, 1, 0.2].forEach((expected, index) => {
      expect(peaks[index]).toBeCloseTo(expected, 5);
    });
  });

  it('keeps silent audio at the minimum bar height', () => {
    const peaks = computePeaks(new Float32Array(100), 5);

    expect(peaks).toHaveLength(5);
    expect(peaks.every(value => value > 0 && value < 0.2)).toBe(true);
  });
});

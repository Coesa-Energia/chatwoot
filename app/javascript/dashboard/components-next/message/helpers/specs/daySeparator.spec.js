import {
  dayKey,
  daySeparatorLabel,
  messageTimeLabel,
  withDaySeparators,
} from '../daySeparator';

const unix = (year, month, day, hour = 12, minute = 0) =>
  Math.floor(new Date(year, month - 1, day, hour, minute).getTime() / 1000);

describe('dayKey', () => {
  it('is the same for two times on one local day and differs across days', () => {
    expect(dayKey(unix(2026, 9, 21, 7, 52))).toBe(
      dayKey(unix(2026, 9, 21, 23, 59))
    );
    expect(dayKey(unix(2026, 9, 21))).not.toBe(dayKey(unix(2026, 9, 22)));
  });
});

describe('daySeparatorLabel', () => {
  const now = new Date(2026, 9, 12, 15, 0); // 12 Oct 2026
  const options = {
    now,
    locale: 'pt_BR',
    todayLabel: 'Hoje',
    yesterdayLabel: 'Ontem',
  };

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(now);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('says today and yesterday', () => {
    expect(daySeparatorLabel(unix(2026, 10, 12, 9), options)).toBe('Hoje');
    expect(daySeparatorLabel(unix(2026, 10, 11, 20), options)).toBe('Ontem');
  });

  it('uses the weekday for the last week', () => {
    // 10 Oct 2026 is a Saturday
    expect(daySeparatorLabel(unix(2026, 10, 10), options)).toBe('sábado');
  });

  it('uses the full date for older days, in the locale format', () => {
    expect(daySeparatorLabel(unix(2026, 9, 21), options)).toBe('21/09/2026');
    expect(
      daySeparatorLabel(unix(2026, 9, 21), { ...options, locale: 'en' })
    ).toBe('09/21/2026');
  });
});

describe('messageTimeLabel', () => {
  it('shows only the time, 24 h for pt-BR', () => {
    expect(messageTimeLabel(unix(2026, 9, 21, 14, 57), 'pt_BR')).toBe('14:57');
  });
});

describe('withDaySeparators', () => {
  it('puts one divider before the first message of every day', () => {
    const entries = [
      { key: 'a', createdAt: unix(2026, 9, 21, 7, 52) },
      { key: 'b', createdAt: unix(2026, 9, 21, 8, 37) },
      { key: 'c', createdAt: unix(2026, 9, 26, 15, 33) },
    ];

    const result = withDaySeparators(entries);

    expect(result.map(entry => entry.key)).toEqual([
      expect.stringMatching(/^date-/),
      'a',
      'b',
      expect.stringMatching(/^date-/),
      'c',
    ]);
    expect(result[0].date).toBe(entries[0].createdAt);
    expect(result[3].date).toBe(entries[2].createdAt);
  });

  it('returns nothing for an empty list', () => {
    expect(withDaySeparators([])).toEqual([]);
  });
});

import {
  fromUnixTime,
  isToday,
  isYesterday,
  differenceInCalendarDays,
} from 'date-fns';

// vue-i18n locales look like pt_BR; Intl wants pt-BR.
const intlLocale = locale => (locale || 'en').replace('_', '-');

// Local calendar day of a unix timestamp, used to decide where a new day starts.
export const dayKey = timestamp => {
  const date = fromUnixTime(timestamp);
  return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
};

// Label of the divider shown above the first message of a day, like the WhatsApp app:
// "Today", "Yesterday", the weekday for the last few days, the date for anything older.
export const daySeparatorLabel = (
  timestamp,
  {
    locale = 'en',
    todayLabel = 'Today',
    yesterdayLabel = 'Yesterday',
    now = new Date(),
  } = {}
) => {
  const date = fromUnixTime(timestamp);
  if (isToday(date)) return todayLabel;
  if (isYesterday(date)) return yesterdayLabel;

  const formatLocale = intlLocale(locale);
  if (differenceInCalendarDays(now, date) < 7) {
    return new Intl.DateTimeFormat(formatLocale, { weekday: 'long' }).format(
      date
    );
  }
  return new Intl.DateTimeFormat(formatLocale, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date);
};

// Time of a message inside its day (the date is on the divider), in the user's usual clock: 24 h for pt-BR.
export const messageTimeLabel = (timestamp, locale = 'en') =>
  new Intl.DateTimeFormat(intlLocale(locale), {
    hour: '2-digit',
    minute: '2-digit',
  }).format(fromUnixTime(timestamp));

/**
 * Inserts a { key, date } entry before the first entry of every day. Entries need a `createdAt` (unix seconds).
 */
export const withDaySeparators = entries => {
  const result = [];
  let currentDay = null;

  entries.forEach(entry => {
    const key = dayKey(entry.createdAt);
    if (key !== currentDay) {
      result.push({ key: `date-${key}`, date: entry.createdAt });
      currentDay = key;
    }
    result.push(entry);
  });

  return result;
};

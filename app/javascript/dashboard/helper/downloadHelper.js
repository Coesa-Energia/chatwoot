import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';
import { downloadFile } from '@chatwoot/utils';

export const downloadCsvFile = (fileName, content) => {
  const contentType = 'data:text/csv;charset=utf-8;';
  const blob = new Blob([content], { type: contentType });
  const url = URL.createObjectURL(blob);

  const link = document.createElement('a');
  link.setAttribute('download', fileName);
  link.setAttribute('href', url);
  link.click();
  return link;
};

const STORAGE_REDIRECT_PATH =
  /\/rails\/active_storage\/(blobs|representations)\/redirect\//;

// Attachment URLs point at ActiveStorage's redirect route, which answers with a
// 302 to the storage bucket (another origin). downloadFile() reads the file
// with fetch(), so following that redirect needs CORS on the bucket; without it
// the download fails while "Save as" (no CORS) works. The proxy route serves the
// same file from our own origin, so fetch() never leaves it.
export const toSameOriginStorageUrl = url => {
  if (!url || typeof window === 'undefined') return url;

  let parsed;
  try {
    parsed = new URL(url, window.location.origin);
  } catch (error) {
    return url;
  }
  if (parsed.origin !== window.location.origin) return url;
  if (!STORAGE_REDIRECT_PATH.test(parsed.pathname)) return url;

  parsed.pathname = parsed.pathname.replace(
    STORAGE_REDIRECT_PATH,
    '/rails/active_storage/$1/proxy/'
  );
  return parsed.toString();
};

export const downloadAttachment = ({ url, ...options }) =>
  downloadFile({ url: toSameOriginStorageUrl(url), ...options });

export const generateFileName = ({ type, to, businessHours = false }) => {
  let name = `${type}-report-${format(fromUnixTime(to), 'dd-MM-yyyy')}`;
  if (businessHours) {
    name = `${name}-business-hours`;
  }
  return `${name}.csv`;
};

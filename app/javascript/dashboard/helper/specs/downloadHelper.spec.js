import { downloadFile } from '@chatwoot/utils';
import {
  downloadAttachment,
  generateFileName,
  toSameOriginStorageUrl,
} from '../downloadHelper';

vi.mock('@chatwoot/utils', () => ({ downloadFile: vi.fn() }));

describe('#generateFileName', () => {
  it('should generate the correct file name', () => {
    expect(generateFileName({ type: 'csat', to: 1652812199 })).toEqual(
      'csat-report-17-05-2022.csv'
    );

    expect(
      generateFileName({ type: 'csat', to: 1652812199, businessHours: true })
    ).toEqual('csat-report-17-05-2022-business-hours.csv');
  });
});

describe('#toSameOriginStorageUrl', () => {
  const origin = window.location.origin;

  it('swaps the blob redirect route for the same-origin proxy route', () => {
    expect(
      toSameOriginStorageUrl(
        `${origin}/rails/active_storage/blobs/redirect/abc--123/Foto%201.png`
      )
    ).toEqual(
      `${origin}/rails/active_storage/blobs/proxy/abc--123/Foto%201.png`
    );
  });

  it('swaps the representation redirect route too', () => {
    expect(
      toSameOriginStorageUrl(
        '/rails/active_storage/representations/redirect/abc/def/thumb.jpg'
      )
    ).toEqual(
      `${origin}/rails/active_storage/representations/proxy/abc/def/thumb.jpg`
    );
  });

  it('keeps the query string', () => {
    expect(
      toSameOriginStorageUrl(
        `${origin}/rails/active_storage/blobs/redirect/abc/doc.pdf?disposition=attachment`
      )
    ).toEqual(
      `${origin}/rails/active_storage/blobs/proxy/abc/doc.pdf?disposition=attachment`
    );
  });

  it('leaves URLs from other origins untouched', () => {
    const url =
      'https://bucket.example.com/rails/active_storage/blobs/redirect/abc/x.png';
    expect(toSameOriginStorageUrl(url)).toEqual(url);
  });

  it('leaves non-storage URLs and empty values untouched', () => {
    expect(toSameOriginStorageUrl(`${origin}/audio.mp3`)).toEqual(
      `${origin}/audio.mp3`
    );
    expect(toSameOriginStorageUrl('')).toEqual('');
    expect(toSameOriginStorageUrl(undefined)).toBeUndefined();
  });
});

describe('#downloadAttachment', () => {
  it('downloads through the proxy route', async () => {
    const origin = window.location.origin;
    await downloadAttachment({
      url: `${origin}/rails/active_storage/blobs/redirect/abc/video.mp4`,
      type: 'video',
      extension: 'mp4',
    });
    expect(downloadFile).toHaveBeenCalledWith({
      url: `${origin}/rails/active_storage/blobs/proxy/abc/video.mp4`,
      type: 'video',
      extension: 'mp4',
    });
  });
});

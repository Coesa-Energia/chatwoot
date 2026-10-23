const WEBHOOK_PATH_PREFIX = '/webhooks/whatsapp';

const parseUrl = value => {
  try {
    return new URL(value);
  } catch (error) {
    return null;
  }
};

/**
 * Meta lets a WhatsApp Business Account (WABA) share one callback URL across all its numbers,
 * and that is a valid setup: for WhatsApp Cloud the inbox is found from the phone number inside
 * the payload, so the trailing `/webhooks/whatsapp/<number>` segment is irrelevant. Comparing the
 * full URL made every number after the first one on a WABA look misconfigured. The webhook is
 * only wrong when it points to another host or to a path that is not our WhatsApp endpoint.
 *
 * @param {string} configuredUrl URL Meta will actually call for this number
 * @param {string} expectedUrl URL this installation would register for the number
 * @returns {boolean}
 */
export const isWhatsappWebhookUrlValid = (configuredUrl, expectedUrl) => {
  if (!configuredUrl || !expectedUrl) return false;
  if (configuredUrl === expectedUrl) return true;

  const configured = parseUrl(configuredUrl);
  const expected = parseUrl(expectedUrl);
  if (!configured || !expected) return false;

  return (
    configured.origin === expected.origin &&
    (configured.pathname === WEBHOOK_PATH_PREFIX ||
      configured.pathname.startsWith(`${WEBHOOK_PATH_PREFIX}/`))
  );
};

/**
 * Meta resolves the callback by priority: phone number override, then the WABA, then the app.
 *
 * @param {Object} webhookConfiguration `webhook_configuration` returned by the Graph API
 * @returns {string|undefined}
 */
export const effectiveWhatsappWebhookUrl = (webhookConfiguration = {}) =>
  webhookConfiguration?.override_callback_uri ||
  webhookConfiguration?.phone_number ||
  webhookConfiguration?.whatsapp_business_account ||
  webhookConfiguration?.application;

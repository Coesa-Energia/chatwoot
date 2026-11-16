// Outgoing messages with files whose POST is still running, keyed by echo_id.
//
// Rails stores the uploaded file only after the message row is committed, and
// the message.created broadcast is queued on that same commit. With large files
// the websocket copy reaches the dashboard seconds before the file is in
// storage, so rendering it makes the browser request a file that does not exist
// yet: the bubble shows "loading failed" and stays that way until a reload.
// While the POST runs we keep the websocket copies here instead of rendering
// them; the POST response only comes back once the file is stored.
const inFlightUploads = new Map();

export const hasFilesToUpload = message =>
  Array.isArray(message?.files) && message.files.length > 0;

export const startInFlightUpload = echoId => {
  inFlightUploads.set(echoId, { created: null, updated: null });
};

export const finishInFlightUpload = echoId => {
  const held = inFlightUploads.get(echoId) || { created: null, updated: null };
  inFlightUploads.delete(echoId);
  return held;
};

const findInFlightKey = message => {
  if (message?.echo_id && inFlightUploads.has(message.echo_id)) {
    return message.echo_id;
  }
  if (!message?.id) return null;

  const match = [...inFlightUploads.entries()].find(
    ([, held]) => held.created?.id === message.id
  );
  return match ? match[0] : null;
};

// Returns true when the websocket event belongs to an upload still in flight;
// the payload is then kept for when the POST finishes instead of rendered.
export const holdIfUploadInFlight = (message, kind) => {
  const key = findInFlightKey(message);
  if (!key) return false;

  const held = inFlightUploads.get(key);
  if (kind === 'created') held.created = message;
  else held.updated = message;
  return true;
};

export const resetInFlightUploads = () => inFlightUploads.clear();

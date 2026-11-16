import types from '../../../mutation-types';
import actions from '../../conversations/actions';
import MessageApi from '../../../../api/inbox/message';
import { resetInFlightUploads } from '../../conversations/helpers/inFlightUploads';

vi.mock('../../../../api/inbox/message', () => ({
  default: { create: vi.fn(), retry: vi.fn() },
}));

const deferred = () => {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
};

const pendingWithFile = {
  id: 'echo-1',
  echo_id: 'echo-1',
  conversation_id: 7,
  conversationId: 7,
  status: 'progress',
  files: [new Blob(['x'])],
  content_attributes: {},
};

const serverMessage = {
  id: 100,
  echo_id: 'echo-1',
  conversation_id: 7,
  message_type: 1,
  status: 'sent',
  attachments: [{ id: 1, data_url: 'https://app/rails/active_storage/x' }],
};

describe('attachment upload in flight', () => {
  let commit;

  beforeEach(() => {
    commit = vi.fn();
    resetInFlightUploads();
    MessageApi.create.mockReset();
  });

  it('does not render the websocket copy before the POST finishes', async () => {
    const request = deferred();
    MessageApi.create.mockReturnValue(request.promise);

    const sending = actions.sendMessageWithData({ commit }, pendingWithFile);
    actions.addMessage({ commit, dispatch: vi.fn() }, serverMessage);
    actions.updateMessage(
      { commit, dispatch: vi.fn(), rootGetters: {}, state: {} },
      { ...serverMessage, echo_id: undefined, status: 'delivered' }
    );

    // Only the pending (progress) copy was rendered so far.
    expect(commit.mock.calls).toEqual([
      [types.ADD_MESSAGE, { ...pendingWithFile, status: 'progress' }],
    ]);

    request.resolve({ data: serverMessage });
    await sending;

    expect(commit.mock.calls.slice(1)).toEqual([
      [types.ADD_MESSAGE, { ...serverMessage, status: 'sent' }],
      [
        types.ADD_CONVERSATION_ATTACHMENTS,
        { ...serverMessage, status: 'sent' },
      ],
      [
        types.ADD_MESSAGE,
        { ...serverMessage, echo_id: undefined, status: 'delivered' },
      ],
    ]);
  });

  it('shows the server copy instead of failing when the request breaks after the message was created', async () => {
    const request = deferred();
    MessageApi.create.mockReturnValue(request.promise);

    const sending = actions.sendMessageWithData({ commit }, pendingWithFile);
    actions.addMessage({ commit, dispatch: vi.fn() }, serverMessage);
    request.reject(new Error('Network Error'));

    await expect(sending).resolves.toBeUndefined();
    expect(commit.mock.calls.slice(1)).toEqual([
      [types.ADD_MESSAGE, serverMessage],
      [types.ADD_CONVERSATION_ATTACHMENTS, serverMessage],
    ]);
  });

  it('still marks the message as failed when the server never created it', async () => {
    MessageApi.create.mockRejectedValue({
      response: { data: { error: 'too big' } },
    });

    await expect(
      actions.sendMessageWithData({ commit }, pendingWithFile)
    ).rejects.toBeTruthy();
    expect(commit.mock.calls.at(-1)).toEqual([
      types.ADD_MESSAGE,
      { ...pendingWithFile, meta: { error: 'too big' }, status: 'failed' },
    ]);
  });

  it('renders websocket messages normally once nothing is uploading', () => {
    actions.addMessage({ commit, dispatch: vi.fn() }, serverMessage);
    expect(commit).toHaveBeenCalledWith(types.ADD_MESSAGE, serverMessage);
  });

  it('does not hold websocket copies for text-only messages', async () => {
    const request = deferred();
    MessageApi.create.mockReturnValue(request.promise);
    const textMessage = { ...pendingWithFile, files: undefined };

    const sending = actions.sendMessageWithData({ commit }, textMessage);
    actions.addMessage({ commit, dispatch: vi.fn() }, serverMessage);
    expect(commit).toHaveBeenCalledWith(types.ADD_MESSAGE, serverMessage);

    request.resolve({ data: serverMessage });
    await sending;
  });
});

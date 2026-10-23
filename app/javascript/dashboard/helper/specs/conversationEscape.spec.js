import {
  shouldCloseConversationOnEscape,
  conversationListUrlForRoute,
} from '../conversationEscape';

describe('shouldCloseConversationOnEscape', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('closes when nothing else is open', () => {
    expect(shouldCloseConversationOnEscape({ defaultPrevented: false })).toBe(
      true
    );
  });

  it('leaves the key to whoever already used it', () => {
    expect(shouldCloseConversationOnEscape({ defaultPrevented: true })).toBe(
      false
    );
  });

  it('does not close under a modal or dialog', () => {
    document.body.innerHTML = '<div class="modal-mask"></div>';
    expect(shouldCloseConversationOnEscape({ defaultPrevented: false })).toBe(
      false
    );
    document.body.innerHTML = '<div role="dialog"></div>';
    expect(shouldCloseConversationOnEscape({ defaultPrevented: false })).toBe(
      false
    );
  });

  it('does not close while the command bar is open', () => {
    document.body.innerHTML = '<ninja-keys></ninja-keys>';
    document.querySelector('ninja-keys').visible = true;
    expect(shouldCloseConversationOnEscape({ defaultPrevented: false })).toBe(
      false
    );
  });
});

describe('shouldCloseConversationOnEscape targets', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('closes while typing in the message editor even though ProseMirror marks Escape as handled', () => {
    document.body.innerHTML =
      '<div class="ProseMirror" contenteditable="true"><p id="p"></p></div>';
    const target = document.getElementById('p');
    expect(
      shouldCloseConversationOnEscape({ target, defaultPrevented: true })
    ).toBe(true);
  });

  it('keeps Escape for other fields', () => {
    document.body.innerHTML = '<input id="i" />';
    const target = document.getElementById('i');
    expect(
      shouldCloseConversationOnEscape({ target, defaultPrevented: false })
    ).toBe(false);
  });

  it('does not close while the emoji picker or a caret picker is open', () => {
    document.body.innerHTML = '<div class="emoji-dialog"></div>';
    expect(shouldCloseConversationOnEscape({ defaultPrevented: false })).toBe(
      false
    );
    document.body.innerHTML = '<div data-escape-owner></div>';
    expect(shouldCloseConversationOnEscape({ defaultPrevented: false })).toBe(
      false
    );
  });
});

describe('conversationListUrlForRoute', () => {
  it('goes back to the inbox list when the conversation was opened from an inbox', () => {
    const route = {
      name: 'conversation_through_inbox',
      params: { inbox_id: 6 },
    };
    expect(conversationListUrlForRoute(route, 1)).toBe(
      '/app/accounts/1/inbox/6'
    );
  });

  it('goes back to the dashboard otherwise', () => {
    const route = { name: 'inbox_conversation', params: {} };
    expect(conversationListUrlForRoute(route, 1)).toBe(
      '/app/accounts/1/dashboard'
    );
  });

  it('maps mention routes to the mentions list', () => {
    const route = { name: 'conversation_through_mentions', params: {} };
    expect(conversationListUrlForRoute(route, 1)).toBe(
      '/app/accounts/1/mentions/conversations'
    );
  });
});

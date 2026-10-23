import {
  findMatchRanges,
  applyChatSearchHighlight,
  clearChatSearchHighlight,
  activeSearchMessageId,
} from '../chatSearchHighlight';

const html = markup => {
  document.body.innerHTML = markup;
  return document.body;
};

describe('findMatchRanges', () => {
  it('finds every occurrence, ignoring case', () => {
    const root = html(
      '<p id="m">Orçamento enviado. O orçamento foi aprovado</p>'
    );

    const ranges = findMatchRanges(root, 'orçamento');

    expect(ranges).toHaveLength(2);
    expect(ranges.map(range => range.toString())).toEqual([
      'Orçamento',
      'orçamento',
    ]);
  });

  it('finds matches inside nested formatting', () => {
    const root = html(
      '<p>Quer <strong>proposta</strong> ou proposta nova?</p>'
    );

    expect(findMatchRanges(root, 'proposta')).toHaveLength(2);
  });

  it('does not look inside the message time', () => {
    const root = html('<p>Chegou 09:37</p><time>09:37</time>');

    expect(findMatchRanges(root, '09:37')).toHaveLength(1);
  });

  it('returns nothing for an empty query or missing root', () => {
    expect(findMatchRanges(html('<p>texto</p>'), '')).toEqual([]);
    expect(findMatchRanges(null, 'texto')).toEqual([]);
  });
});

describe('applyChatSearchHighlight / clearChatSearchHighlight', () => {
  afterEach(() => {
    clearChatSearchHighlight();
  });

  it('tracks the active message even when the browser has no highlight API', () => {
    html(
      '<div id="message1">olá mundo</div><div id="message2">olá de novo</div>'
    );

    applyChatSearchHighlight({ query: 'olá', messageIds: [1, 2], activeId: 2 });
    expect(activeSearchMessageId.value).toBe(2);

    clearChatSearchHighlight();
    expect(activeSearchMessageId.value).toBeNull();
  });
});

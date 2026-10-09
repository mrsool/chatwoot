import {
  buildSearchParamsWithLocale,
  getLocale,
  getRequestedConversationId,
  isNavigationHidden,
  buildPopoutURL,
} from '../urlParamsHelper';

describe('#buildSearchParamsWithLocale', () => {
  it('returns correct search params', () => {
    let windowSpy = vi.spyOn(window, 'window', 'get');
    windowSpy.mockImplementation(() => ({
      WOOT_WIDGET: {
        $root: {
          $i18n: {
            locale: 'el',
          },
        },
      },
    }));
    expect(buildSearchParamsWithLocale('?test=1234')).toEqual(
      '?test=1234&locale=el'
    );
    expect(buildSearchParamsWithLocale('')).toEqual('?locale=el');
    windowSpy.mockRestore();
  });
});

describe('#getLocale', () => {
  it('returns correct locale', () => {
    expect(getLocale('?test=1&cw_conv=2&locale=fr')).toEqual('fr');
    expect(getLocale('?test=1&locale=fr')).toEqual('fr');
    expect(getLocale('?test=1&cw_conv=2&website_token=3&locale=fr')).toEqual(
      'fr'
    );
    expect(getLocale('')).toEqual(null);
  });
});

describe('#getRequestedConversationId', () => {
  it('returns the requested conversation id', () => {
    expect(getRequestedConversationId('?conversation_id=15')).toEqual('15');
    expect(
      getRequestedConversationId('?website_token=3&conversation_id=16&locale=en')
    ).toEqual('16');
  });

  it('returns null when none is requested', () => {
    expect(getRequestedConversationId('?website_token=3&locale=en')).toEqual(
      null
    );
    expect(getRequestedConversationId('')).toEqual(null);
  });
});

describe('#isNavigationHidden', () => {
  it('is hidden only when the host asks for it', () => {
    expect(isNavigationHidden('?hide_nav=1')).toBe(true);
    expect(isNavigationHidden('?website_token=3&hide_nav=1&locale=en')).toBe(
      true
    );
  });

  it('is not hidden by default', () => {
    expect(isNavigationHidden('?website_token=3&locale=en')).toBe(false);
    expect(isNavigationHidden('')).toBe(false);
  });

  // Anything but an explicit 1 leaves the widget's own navigation in place,
  // so a stray or truncated value cannot strand the user on one thread.
  it('ignores values other than 1', () => {
    expect(isNavigationHidden('?hide_nav=0')).toBe(false);
    expect(isNavigationHidden('?hide_nav=true')).toBe(false);
    expect(isNavigationHidden('?hide_nav=')).toBe(false);
  });
});

describe('#buildPopoutURL', () => {
  it('returns popout URL', () => {
    expect(
      buildPopoutURL({
        origin: 'https://chatwoot.com',
        conversationCookie: 'random-jwt-token',
        websiteToken: 'random-website-token',
        locale: 'ar',
      })
    ).toEqual(
      'https://chatwoot.com/widget?cw_conversation=random-jwt-token&website_token=random-website-token&locale=ar'
    );
  });
});

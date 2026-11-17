// What a push says, in the recipient's language. Pure, so it can be tested.

export type Kind = 'nudge' | 'cheer' | 'friend_request' | 'friend_activity';
export type Language = 'de' | 'en';

export interface Message {
  title: string;
  body: string;
}

/** Texts friends typed travel as they are; everything else is a template. */
export function messageFor(kind: Kind, language: Language, sender: string, text?: string): Message {
  const de = language === 'de';
  const name = sender.trim() || (de ? 'Jemand' : 'Someone');
  const typed = (text ?? '').trim().slice(0, 180);
  switch (kind) {
    case 'nudge':
      return {
        title: de ? `${name} stupst dich an 👀` : `${name} nudged you 👀`,
        body: typed || (de ? 'Heute schon dran gewesen?' : 'Have you shown up today?'),
      };
    case 'cheer':
      return {
        title: de ? `${name} feiert dich 🔥` : `${name} cheers you on 🔥`,
        body: typed || (de ? 'Weiter so.' : 'Keep going.'),
      };
    case 'friend_request':
      return {
        title: de ? 'Neue Freundschaftsanfrage' : 'New friend request',
        body: de ? `${name} will mit dir die 100 Tage machen.` : `${name} wants to do the 100 days with you.`,
      };
    case 'friend_activity':
      return {
        title: de ? `${name} war heute schon dran` : `${name} already showed up today`,
        body: de ? 'Und du? Dein Tag ist noch offen.' : 'And you? Your day is still open.',
      };
  }
}

/** The FCM HTTP v1 request body for one device. */
export function fcmBody(token: string, message: Message, kind: Kind): unknown {
  return {
    message: {
      token,
      notification: { title: message.title, body: message.body },
      data: { kind },
      android: { priority: 'high', notification: { channel_id: 'friends' } },
      apns: { payload: { aps: { sound: 'default' } } },
    },
  };
}

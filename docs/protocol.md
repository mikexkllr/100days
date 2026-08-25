# Protokoll

Ziel: Zwei Geräte, die sich sehen, gleichen ihre Feeds in einer Runde ab und
legen auf. Es gibt keinen Client und keinen Server — beide Seiten führen
dieselbe Routine aus.

## Identität

Ed25519-Schlüsselpaar, erzeugt auf dem Gerät aus 32 Byte Zufall. Adressiert als
`did:key:z…` (Multicodec-Präfix `0xed 0x01`, Base58btc). Der Seed liegt im
Keychain bzw. Android Keystore und ist der gesamte Account — es gibt keinen
Anbieter, der ihn zurücksetzen könnte.

Der Wiederherstellungs-Key ist derselbe Seed in Base58. Base58 statt Base64,
weil das Alphabet keine verwechselbaren Zeichen enthält: `0/O` und `1/l/I`
fehlen, was zählt, sobald jemand die Zeichenkette vom Bildschirm abschreibt.

## Ereignisformat

```json
{
  "author": "did:key:z6Mk…",
  "seq": 42,
  "prev": "9f2c…",
  "timestamp": "2026-03-14T18:22:05.000Z",
  "type": "checkin",
  "payload": { "habitId": "gym", "category": "gym", "day": "2026-03-14",
               "value": 1, "streak": 41 },
  "hash": "a17b…",
  "sig": "MEUCIQ…"
}
```

- `hash` = SHA-256 über `canonicalJson({author, seq, prev, timestamp, type,
  payload})`. Kanonisch heißt: Objektschlüssel sortiert, kein Leerraum, ganze
  Gleitkommazahlen als Ganzzahlen. Ohne diese Festlegung leiten zwei
  Implementierungen unterschiedliche Bytes ab und keine Signatur prüft mehr.
- `sig` = Ed25519 über die UTF-8-Bytes von `hash`, Base64.
- `prev` ist `null` genau beim ersten Ereignis (`seq == 1`).

Ereignistypen: `profile`, `challenge.started`, `challenge.ascended`, `checkin`,
`missed`, `streak.freeze`, `nudge`, `cheer`, `friend.request`.

## Prüfregeln beim Empfang

Ein Ereignis wird angenommen, wenn **alle** zutreffen:

| Prüfung | Ablehnungsgrund |
| --- | --- |
| Typ ist bekannt | `unknownType` |
| `hash` entspricht dem kanonischen Rumpf | `badHash` |
| `timestamp` ≤ jetzt + 10 min | `timestampInFuture` |
| `seq` == Vorgänger + 1 (bzw. 1) | `seqOutOfOrder` |
| `prev` == Hash des Vorgängers | `chainBroken` |
| `timestamp` ≥ Zeitstempel des Vorgängers | `timestampRegression` |
| Signatur prüft gegen `author` | `badSignature` |

Nach dem ersten abgelehnten Ereignis eines Autors wird der Rest **dieses**
Autors in derselben Lieferung verworfen: Hinter einem gebrochenen Glied ist
nichts mehr überprüfbar, und weiterzumachen hieße, sich einen gefälschten
Schwanz unterschieben zu lassen.

Eintreffende Ereignisse, deren Vorgänger fehlt, werden zurückgehalten statt
abgelehnt — die nächste Runde fordert die Lücke an.

## Ablauf einer Runde

Rahmung: ein JSON-Objekt pro Zeile (NDJSON) über TCP. Bewusst langweilig,
damit ein zweiter Client davon implementierbar bleibt.

```
A                                        B
│── hello {did, name, v} ───────────────►│
│◄─────────────── hello {did, name, v} ──│
│── have {heads:[{did,seq,hash}, …]} ───►│
│◄──────────────────────── have {heads} ─│
│── want {ranges:[{did, from}, …]} ─────►│
│◄──────────────────────── want {ranges} │
│── events {events:[…], more} ──────────►│
│── done ───────────────────────────────►│
│◄───────────────────────────── events ──│
│◄─────────────────────────────── done ──│
```

Die Runde endet, wenn beide Seiten `done` gesendet *und* empfangen haben. Ein
Gerät, das mitten in der Runde aus dem WLAN läuft, hinterlässt beide Seiten
konsistent — jedes einzelne Ereignis ist für sich prüfbar, es gibt nichts, was
"halb angekommen" wäre.

**Sequentiell verarbeitet.** Ein Rahmen wird vollständig angewandt, bevor der
nächste gelesen wird. Nebenläufig zu verarbeiten hieße, dass ein `done`
eintrifft, während ein Stapel Ereignisse noch geschrieben wird — die Runde
meldete dann Erfolg über einen halb replizierten Feed.

**Grenzen.** Höchstens 200 Ereignisse pro Rahmen, höchstens 4 MB pro Zeile.
Ein Gegenüber soll uns nicht dazu bringen können, seine gesamte Historie auf
einmal im Speicher zu halten.

**Nur Gefolgte.** Angeboten und angenommen werden ausschließlich Feeds aus der
eigenen Freundesliste (plus der eigene). Sonst landet die Freundesliste der
Freundesliste unbemerkt auf dem Gerät.

## Transporte

`PeerTransport` liefert Entdeckungen und Sitzungen; der `Syncer` weiß nicht,
worüber er spricht.

**LAN** (mitgeliefert): UDP-Multicast-Beacon auf `239.100.100.1:47101` alle
fünf Sekunden mit `{did, name, port}`, Replikation über TCP. Braucht keine
Infrastruktur — Mitbewohner und Trainingspartner sind physisch nah. Scheitert
das Multicast (Gast-WLAN, Mobilfunk), bleibt der TCP-Teil nutzbar für Adressen
aus einer gescannten Einladung.

Pro Peer greift eine Sperre von 20 Sekunden: Ein Gerät, das sich alle fünf
Sekunden meldet, darf nicht alle fünf Sekunden eine Runde auslösen.

## Einladungen

```
hundreddays://invite?d=<base64url({did, name, emoji, addr[], ts})>
```

Es gibt keine Registry, in der man jemanden nachschlägt, also trägt die
Einladung selbst alles Nötige. Die Adressen sind eine Abkürzung für "wir sind
gerade im selben WLAN", kein dauerhafter Anker — danach übernimmt die
Entdeckung.

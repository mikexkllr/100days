# Stand und offene Punkte

Ehrliche Liste. Was hier steht, ist noch nicht gebaut.

## Läuft

- Onboarding mit Zielsetzung, abgeleiteten Gewohnheiten und Planvorschau
- Check-ins, Rückfälle, Streak-Freeze, Zyklusaufstieg — alles signiert
- Trainingsplan (Mesozyklen mit Deload, RPE, Equipment-Fallback),
  Ernährungsplan (Mifflin-St Jeor, Makros, Mahlzeitenaufteilung),
  Abstinenz-Meilensteine
- Regelbasierter Coach, Modell-Port für lokale Inferenz
- Feed, Wochenliga, Anstupser, Feiern, QR-/Link-Einladungen
- LAN-Entdeckung und Replikation, lokale Benachrichtigungen
- Wiederherstellungs-Key, vollständiges Löschen

## Offen

**Inferenz-Engine.** `GgufLlmRuntime.attachBackend` ist der Steckplatz; es
fehlt die Bindung an llama.cpp (FFI) oder MediaPipe. Bis dahin läuft immer der
regelbasierte Coach.

**Relay-Transport.** Freunde außerhalb des eigenen WLANs erreicht man derzeit
nur, wenn man sich physisch trifft. Ein Nostr-artiges Relay oder WebRTC hinter
`PeerTransport` würde das lösen, ohne den Serverlos-Anspruch zu brechen — das
Relay leitet verschlüsselte, signierte Bytes weiter und kann sie nicht lesen.

**Hintergrund-Sync.** Aktuell wird beim App-Start und beim Zurückkehren in den
Vordergrund synchronisiert. Auf Android wäre WorkManager möglich; iOS erlaubt
im Hintergrund praktisch nichts Verlässliches, was hier ehrlich benannt gehört.

**Bluetooth-Transport.** Für den Fall "gleiche Turnhalle, kein gemeinsames
WLAN". BLE-Durchsatz reicht für Feed-Deltas locker.

**Ende-zu-Ende-Verschlüsselung der Nutzlast.** Ereignisse sind signiert, aber
im Klartext. Solange nur direkt zwischen Freundesgeräten repliziert wird, ist
das vertretbar; sobald ein Relay dazwischenliegt, ist es das nicht mehr.

**Gruppen-Challenges.** Mehrere Leute auf dasselbe Ziel, gemeinsamer
Fortschritt. Datenmodell trägt das bereits, die Oberfläche nicht.

**Widgets und Wearables.** Ein Homescreen-Widget mit dem Streak wäre die
billigste Erinnerung, die es gibt.

**Import aus Health/Google Fit.** Schritte und Trainingsdauer automatisch statt
per Hand.

**Lokalisierung.** Die Oberfläche ist durchgehend deutsch und nicht über ARB
externalisiert.

**BIP39-Merkphrase.** Der Wiederherstellungs-Key ist Base58 statt zwölf Wörter.
Funktional gleichwertig, aber schwerer abzuschreiben.

**Signierte Releases.** Die Android-Konfiguration nutzt noch den Debug-Key.

# 100 Tage — und weit darüber hinaus

Eine offene Challenge-App für iOS und Android. Du setzt am Anfang ein Ziel,
bekommst daraus einen Trainings- oder Ernährungsplan oder schlicht einen
Tagesstreak — und deine Freunde sehen jeden Tag, ob du dran warst.

Kein Konto. Kein Server. Keine Cloud. Deine Daten liegen auf deinem Gerät und
gehen direkt zu den Leuten, die du selbst verbunden hast.

> **English:** A local-first, peer-to-peer habit challenge app built with
> Flutter. Self-sovereign Ed25519 identity, a signed hash-chained activity feed
> that makes streaks independently verifiable, an on-device coach, and gossip
> replication with no backend. Ships in English and German, following the
> device language.

---

## Warum es anders funktioniert als die anderen

**Der Streak ist beweisbar.** Jeder Check-in ist ein signierter Eintrag in
einem hash-verketteten Log. Deine Freunde rechnen deinen Streak aus *deinen
Einträgen* aus — du behauptest ihn nicht, du beweist ihn. Ein nachträglich
eingeschobenes Training bricht die Kette, ein nachgetragener Tag ist im Feed
sichtbar als "nachgetragen" markiert.

**Der Druck kommt von echten Leuten.** Nicht "3 Nutzer waren heute aktiv",
sondern: Marcel war heute im Gym, hat 47 Tage Streak, und du stehst noch auf
null. Wochenliga mit Auf- und Abstieg, Anstupser, Feiern. Das Duolingo-Prinzip,
nur ist der Pool deine eigenen Freunde — gegen Fremde zu verlieren kostet
nichts, gegen den eigenen Mitbewohner schon.

**Es hört bei Tag 100 nicht auf.** Tag 100 schließt einen Zyklus ab. Danach
steigst du eine Stufe auf, der Streak läuft weiter, die Ziele werden härter.

**Niemand sieht mit.** Es gibt keinen Server, der deine Rückfälle kennt, weil
es überhaupt keinen Server gibt. Der Coach läuft auf dem Gerät.

**Deutsch und Englisch.** Die App folgt der Systemsprache; umstellen geht in
den Einstellungen. Details: [`docs/localization.md`](docs/localization.md).

## Was du tracken kannst

🏋️ Training · 🏃 Cardio · 🥗 Ernährung · 🚱 Kein Alkohol · 🍬 Kein Zucker ·
🧠 Dopamin-Detox · 🛡️ NoFap · 🚭 Kein Nikotin · 📚 Lesen · 🧘 Meditation ·
🧊 Kalt duschen · 😴 Schlaf · 💧 Wasser · ✍️ Journaling · ⭐ Eigenes

Gewohnheiten sind entweder **Aufbau** (etwas tun) oder **Verzicht** (etwas
lassen), und das ändert, wie gezählt wird: ein vergessener Haken killt keine
Abstinenz-Serie, ein eingestandener Rückfall schon.

## Was die App generiert

| Ziel | Was daraus wird |
| --- | --- |
| Muskeln aufbauen / Fett verlieren / Fit werden | Trainingsplan mit Split nach Trainingstagen, Mesozyklen aus drei Aufbauwochen plus Deload, RPE statt Wunschgewichten — und Kalorien-/Makroziele nach Mifflin-St Jeor |
| Disziplin / Kopf frei / Clean bleiben | Tagesstreak mit Meilenstein-Track: was an Tag 3, 14, 30, 90 im Körper und im Kopf passiert |

Beides wird **deterministisch auf dem Gerät** berechnet. Gleiche Eingaben,
gleicher Plan — nachvollziehbar statt Blackbox, und funktioniert im Kellergym
ohne Empfang.

## Der Coach auf dem Gerät

Zwei Implementierungen hinter einem Interface:

- **Regelbasiert** (immer aktiv): wählt den Ton aus dem Zustand — Aufbruch,
  sozialer Druck, "der Tag ist gleich rum", Meilenstein, Rückfall. Braucht kein
  Modell, antwortet sofort, funktioniert offline.
- **Lokales Sprachmodell** (optional): ein GGUF-Modell, das du selbst in den
  Modellordner legst. Der Prompt verlässt das Gerät nie. Fällt bei jedem
  Fehler — kein Modell, zu langsam, unbrauchbare Ausgabe — lautlos auf den
  regelbasierten Coach zurück.

Die App lädt **kein** Modell von selbst herunter. Ein Gigabyte über Mobilfunk
ist nichts, was ohne Nachfrage passieren sollte. Details:
[`docs/local-ai.md`](docs/local-ai.md).

## Wie das Netzwerk funktioniert

Deine Identität ist ein Ed25519-Schlüsselpaar, adressiert als W3C
[`did:key`](https://w3c-ccg.github.io/did-method-key/). Freunde fügst du per
QR-Code oder Link hinzu — es gibt keine Registry, in der man jemanden
nachschlägt.

Repliziert wird per Gossip: Zwei Geräte tauschen die Köpfe ihrer Feeds aus,
fordern an, was fehlt, und legen auf. Kein Client, kein Server, keine Sitzung,
die jemand offen halten muss. Der mitgelieferte Transport findet Freunde im
selben WLAN (UDP-Beacon + TCP); weitere Transporte hängen hinter demselben
Interface. Protokoll: [`docs/protocol.md`](docs/protocol.md).

## Loslegen

```bash
flutter --version        # 3.27 oder neuer
cd app
flutter pub get
flutter run
```

Fertige APK zum Ausprobieren: letzter grüner CI-Lauf → **Actions → CI →
android-build** → Artefakt `hundred-days-apk`. Ausführlich inklusive iPhone:
[`docs/testing-on-device.md`](docs/testing-on-device.md).

Analyse und Tests für beide Pakete:

```bash
cd packages/hundred_core && dart pub get && dart analyze && dart test
cd ../../app             && flutter pub get && flutter analyze && flutter test
```

## Aufbau

```
packages/hundred_core/   Reines Dart: Identität, signierter Feed, Domäne,
                         Plangenerator, Coach, Sync-Protokoll
app/                     Flutter: UI, SQLite, Keystore, Transporte,
                         Benachrichtigungen
```

Der Kern kennt weder Flutter noch Netzwerk noch Dateisystem — und keine
Anzeigesprache. Alles, was stimmen *muss* — Kettenprüfung, Streak-Arithmetik,
Kalorienrechnung, Sync-Runden — ist damit ohne Gerät testbar, und dieselben
Regeln treiben einen deutschen wie einen englischen Nutzer.
Mehr dazu: [`docs/architecture.md`](docs/architecture.md).

## Stand

Was läuft: Onboarding, Check-ins, Streaks, Pläne, Coach, Feed, Liga, Anstupser,
Einladungen, LAN-Sync, lokale Benachrichtigungen, Wiederherstellungs-Key.

Was noch fehlt, ist ehrlich aufgelistet in [`docs/roadmap.md`](docs/roadmap.md)
— unter anderem eine echte Inferenz-Engine hinter dem Modell-Port, ein
Relay-Transport für Freunde außerhalb des WLANs und Hintergrund-Sync auf iOS.

## Lizenz

MIT — siehe [`LICENSE`](LICENSE).

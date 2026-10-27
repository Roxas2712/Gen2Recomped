# Pokémon X/Y: native Integration · 27.10.2026

## Aktueller Stand

Der anschließende [Gebietswechsel-Nachtest](transition-optimization.md) ergänzt
zwei Backend-Optimierungen und einen kontrollierten Alt–Neu–Neu–Alt-Vergleich.
Die geprüfte Strecke zeigt dort die früheren großen Pausen nicht mehr;
deren vollständige kausale Behebung bleibt mangels Reproduktion im alten
Kontrollstand unbewiesen. Die beobachtete mittlere native Arbeit sinkt um rund7%.

Beide eigenen USA-Ausgaben sind kompiliert und wurden im normalen Fenster des
Forks gestartet und bedient. X und Y haben Bibliothekskarten, Vorschau,
3DS-Cartridges, Mod-Verwaltung und eigene Grafik-/Screen-Einstellungen.
Der frühere externe Machbarkeitstest ist durch eine eingebettete C-ABI-Brücke
zum Zakuro-System ergänzt. Der normale Launcher und beide Direktstarter nutzen
jetzt diesen Weg. Die ältere Lua-Spielengine wird für X/Y nicht aufgerufen.

Die Reihenfolge ist Cartridge-Animation → vollständiges Recompiled-Ascendant-
Intro → Spiel. Das Intro endet nach Lugias Flug bei 13,1 Sekunden, ohne
OmegaDias-/Augen-Fortsetzung. Echte LÖVE-Renderprüfungen bestätigen Szenen,
Audiodaten, Ablaufmarken und Ressourcenfreigabe. Die beigefügten
[Logo-](ascendant-intro.png) und [Lugia-Aufnahmen](lugia-sweep.png) stammen daraus.

Die Bedienung, Screen-Optionen, Controller-/Touch-Belegung und Grenzen sind in
[POKEMON-XY.md](../../POKEMON-XY.md) dokumentiert. Die Vollständigkeit einer
Spielkampagne, physische Controller und mobile Geräte sind nicht abgenommen.

## Originaleingabe und erster Ladebefund

Der vorhandene Dump ist **Pokémon X USA**, Title ID `0004000000055D00`,
Produktcode `CTR-P-EKJA`, Basisversion 0. Er ist 1.807.300.928 Bytes groß.
Beide vorhandenen CIA-Inhalte bestehen ihre vollständigen TMD-SHA-256-Prüfungen.
Das bestätigt die Übereinstimmung mit den mitgelieferten Metadaten, nicht
Authentizität oder eine Prüfung gegen eine unabhängige Referenz-ROM.

Die äußere CIA-Inhaltsverschlüsselung ist aus. Die innere NCCH-Verschlüsselung
ist jedoch weiterhin markiert; erweiterter Header, ExeFS- und RomFS-Superblock
bestehen **keine** Klartext-Hashprüfung. Zusammen mit den tatsächlichen
Ladefehlern spricht das für einen weiterhin verschlüsselten inneren Dump.
Die Bezeichnung „RF“ im Dateinamen bedeutet keine vollständige Entschlüsselung.

Der Nutzer hat bestätigt, dass kein zusätzlicher entschlüsselter Dump
vorliegt. Das war zunächst ein Hindernis, ließ sich aber lokal lösen:
Das Spiel verwendet klassische NCCH-Kryptomethode 0. Das separat bezogene
Werkzeug [3DS-Decrypt](https://github.com/aszuraz/3DS-Decrypt/tree/bbe6514f0a575512b8e3d26455b78da32249d5b6)
enthält die dafür veröffentlichten festen Plattformschlüssel. Zunächst
wurden alle drei kleinen Headerbereiche im Speicher entschlüsselt und gegen
ihre Hashes geprüft. Anschließend wurde ausschließlich die ausführbare
Partition in eine **separate private CXI-Arbeitsdatei** übertragen und dort
mit dem unveränderten Werkzeug entschlüsselt.

Die Klartext-Hashes aller drei Bereiche bestehen jetzt. Ein erneuter
SHA-256-Abgleich bestätigt, dass die originale CIA unverändert ist.
Die entschlüsselte Arbeitsdatei liegt unter
`.local/pokemon-x/decrypted/pokemon-x-usa.cxi` und bleibt außerhalb von Git.
Es wurden weder weitere Spiele noch Firmwareabbilder heruntergeladen.

## Reproduzierbare Grundlage

- 3dsrecomp `cec1270db38411f9c02d3f356fc3ed6c3f007424`, MIT.
- Zakuro `e174910de5e7285581b153cbce05543efb135cd5`, MIT.
- 3DS-Decrypt `bbe6514f0a575512b8e3d26455b78da32249d5b6`, GPL-3.0;
  nur privater ursprünglicher Checkout, keine Schlüssel im Fork.
- Mac-GPU: Apple M3, MoltenVK 1.4.2 und Vulkan Loader 1.4.363.0.
  Der Portabilitätspatch aktiviert Vulkan-Portabilität auf macOS;
  D32S8 ersetzt das fehlende D24S8 über den vorhandenen Backend-Fallback.
- X und Y erzeugten je 622 C-Dateien / 487 Kompilationseinheiten.
  Die privaten Bibliotheken wurden in 1.236,9 bzw. 1.977,2 Sekunden gebaut.
- Beide Originaldateien blieben unverändert. Y ist bereits im Klartext;
  seine drei NCCH-Bereichshashes bestehen trotz veraltetem Verschlüsselungsflag.

[results.json](results.json) hält den ursprünglichen Preflight-Zustand fest;
[backend-results.json](backend-results.json) ergänzt den aktuellen Stand.
[diagnostics.txt](diagnostics.txt) bewahrt die ursprünglichen Ladefehler als
historische Diagnose, nicht als aktuellen Startfehler.

## Nachgewiesener Umfang

Die ursprünglichen Compilerprüfungen bestehen (3 Tests), ebenso begrenzte
Container-/Hash-/Argumenttests. Native Smoke-Tests beider Editionen haben je
300 emulierte Frames mit GPU und überwiegend kompilierten Instruktionen beendet.
Das ist Startabdeckung und keine FPS-Prognose für spätere Spielszenen.
Interaktive Fensterläufe erreichten deutsche Sprachwahl, Titel und Einleitung.

Die Geräteschranke wärmt 120 Frames auf und misst 360 weitere. Sie verlangt
GPU + nativen Spielcode, volle Emulationstaktung (~59,83 Hz) und p95 ≤33,4 ms.
Bei Bedarf folgt ein Versuch mit 1×. Das qualifiziert den Startzustand;
anhaltende Gameplay-, Temperatur- und Szenenlast braucht weitere Messungen.
Spielbildrate und Emulationstakt sind unterschiedliche Größen.

Präsentationstests prüfen Layout, Leerausblendung, Touch-/Controller-Belegung
und die Trennung der Sprachpräferenz vom Spielstand. Die neutrale untere
X/Y-Fläche wurde bei 1× bis 8× erfasst; X/Y stimmen bei 3× unabhängig überein.
Die Spracherkennung nutzt exakte eigene Bildbereichs-Fingerprints und bestätigt
keine unbekannten Dialoge. Das Rücksetzen verändert nur die Launcher-Präferenz.

Die Frame-Optimierung verwendet wiederverwendbare ImageData-Puffer, direkte
Kopien aus nativem Speicher und vollständige Bild-Hashes, um unveränderte
Bilder und Leertests nicht erneut zu übertragen/berechnen. Frühere parallele
GPU-Messungen unter hohem Swap-Druck gelten ausdrücklich nicht als Nachweis
einer Verbesserung. Der [isolierte Vergleich](performance-native.json) verwendet zweimal je
200 Frames pro Version in alternierender Reihenfolge auf derselben Professor-
Platan-Szene bei 3×. Native Frame-Arbeit inklusive Leertest sank im Mittel von
4,27 auf 2,38 ms (44,2 %). Der Leertest allein sank von etwa 2,31 auf 0,004 ms.
Die Bild-Hashprüfung erhöht die Frame-/Readback-Arbeit leicht; in Summe ist die
geprüfte Szene schneller. LÖVE-Upload, Audiopacing, Bildschirmpräsentation und
spätere Spielszenen sind in dieser Messung nicht enthalten.

Abschließend bestehen 28 Python-Tests, 65 Launcher- und 4 externe Ablaufchecks,
8 Präsentations-, 10 Sprachpräferenz-, 13 Controller-/Layout- sowie
8 Softwaretastatur-Checks. Der kompilierte Bridge-Stand besteht 10 Rust-Tests.
Ein echter nativer Y-Lauf bei 3× erkennt alle acht Sprachdialogzustände,
bestätigt die gemerkte deutsche Wahl über zwei neue Startzyklen und lässt nach
Reset wieder die manuelle Auswahl stehen (219 Checks inklusive Frames).
Die tatsächliche erste Namenseingabe wurde inzwischen über das spielinterne
Touch-Keyboard bedient. Spätere native Keyboard-Applets und physische Controller
bleiben offen.

Die drei aktiven Chats koordinierten ihre Hardwarepakete nacheinander über
eine gemeinsame Prozesssperre einschließlich QA-Initialisierung und Cleanup.
Alle eigenen Testkinder wurden beendet; Swap-/VM-Dateien und fremde Prozesse
wurden nicht entfernt.

Private ROMs, erzeugter Spielcode, Bibliotheken, Originalassets, Schlüssel und
Spielstände bleiben außerhalb von Git. Vorbestehende fremde Löschungen unter
`docs/qa/retro-launcher/` bleiben unangetastet.

## Sichtbare Dateimod und längere Gameplay-Prüfung

`pokemon_xy_testmod.py` erzeugt aus dem eigenen Dump zwei winzige BPS-Patches
für die englische und deutsche Professor-Begrüßung. Der normale Importer
unterstützt jetzt auch das vom Backend gelesene `romfs_ext`-Verzeichnis.
Der tatsächliche Y-3×-Vergleich aus frischen QA-Profilen ist
[aus](testmod-y-off-before.png) → [an](testmod-y-on.png) →
[wieder aus](testmod-y-off-after.png). Beide Aus-Bilder stimmen bytegenau
überein, das An-Bild zeigt den eigenen Marker im Spieltext.
[Hashes und Umfang](testmod-y-ab.json) sichern diesen Vergleich.

Die private Testmod ist für beide Editionen installiert und zunächst geparkt.
Der sichtbare GPU-Vergleich ist für Y auf Englisch nachgewiesen; X und die
deutsche Patchdatei sind erstellt und gegen ihre Quelldateien geprüft, aber
nicht durch diesen Bildvergleich abgenommen. Der Patch ändert weder Kämpfe
noch Spielstände. Der Importtest deckte einen echten Fehler auf: `romfs_ext`
fehlte in der Importfreigabe, obwohl das Backend dieses Verzeichnis unterstützt.

Fünf Fensterläufe ergeben zusammen 47,93 Minuten, einschließlich Dialogen,
Wartezeiten und Bedienung. Sie verwenden das echte Produktionsfrontend mit
GPU, Audio und gewöhnlichen, teilweise geskripteten 3DS-Tasteneingaben in einem
eigenen QA-Profil. Abgedeckt sind deutsche Charakteranlage, Namenseingabe per
Ingame-Touch-Keyboard, Umziehen, Haus und Wohnzimmer, Escissia, Route 1,
Aquarellia, Starterwahl und Sannahs erster Trainerkampf. Dieser eine Kampf
wurde abgeschlossen und zweimal aus dem selbst erspielten QA-Schnellstand
wiederholt; es sind nicht drei verschiedene Gegner. Alle Läufe kehrten in die
Oberwelt zurück. Anschließend wurde Aquarellia → Route 1 → Escissia und zurück
gelaufen: [Südweg](area-y-escissia-return.png),
[Rückweg](area-y-aquarellia-return.png), [Attacke](battle-y-attack.png),
[Kampfende/Oberwelt](battle-y-return.png).

Der [abschließende achtminütige Lauf](gameplay-slot-5.json) fand praktisch
durchgehend im aktiven Fenster statt, bei 3× und ausgeschaltetem Stereo:

| Abschnitt | Emulation inklusive Wartezeiten | Ausgabe-p95 | Größter beobachteter nativer Frame außerhalb QA-Aufnahmen |
| --- | ---: | ---: | ---: |
| Erste vollständige Wiederholung | 59,81 Hz | 17,83 ms | 27,80 ms |
| Zweite vollständige Wiederholung | 59,68 Hz | 17,74 ms | 19,95 ms |
| Rückweg über die Gebiete | 59,54 Hz | 17,93 ms | 61,17 ms |

Beim ersten Kampfabschluss wurden außerdem 94,20 ms beobachtet. Die Emulation
lief in den Wiederholungen weitgehend flüssig; das ist keine Zusage von
60 gerenderten Spielbildern pro Sekunde. Regelmäßige Fenster-Redraws allein
würden einen stehenden Emulator nicht erkennen. Deshalb werden Framefortschritt
und native Arbeit separat ausgewertet. [Eingaben](gameplay-battle-inputs.jsonl),
[komprimierte Rohmessung](gameplay-battle-frames.csv.gz) und der lesende
Auswerter `tools/pokemon_xy_gameplay_report.py` erlauben die Nachprüfung.

Eine pauschale Ruckelfrei-Abnahme besteht **nicht**. Der
[frühere Außenbereich-Lauf](gameplay-slot-2.json) enthält im aktiven Fenster
native Pausen von 312, 569 und 146 ms bei Haus-/Gebietsabschnitten.
Der größte Ausschlag von 2,72 Sekunden lag dagegen im Hintergrundbetrieb.
Ein [weiterer Diagnose-Lauf](gameplay-slot-4.json) zeigt dort bei einem
1.107-ms-Emulationsaufruf nur 11,12 ms Thread-CPU-Zeit: Das weist auf Wartezeit
hin, beweist aber weder App Nap noch einen bestimmten Treiberfehler.
Diese Befunde begründen keine pauschale Einstufung des M3 als zu schwach.
Die längsten aktiven Ladepausen bleiben gezielt zu profilieren.

QA-Aufnahmen und Schnellstandaktionen sind markiert und aus den
Verteilungswerten ausgespart. Der 75,96-ms-Ausschlag im
[ersten Lauf](gameplay-slot-1.json) folgt unmittelbar einer PNG-Aufnahme und
ist kein belegter Spielruckler. Neu angeforderte Diagnosebilder verbergen den
auslösenden langsamen Frame nicht mehr. Die zehn nativen Bridge-Tests bestehen
auch mit Thread-CPU-Diagnose; der [Testlog](native-bridge-tests.log) ersetzt
lokale Benutzerpfade durch Platzhalter.

Die vier ursprünglichen Benutzer-Savedateien stimmen nach Abschluss weiterhin
mit ihren vorher aufgenommenen SHA-256-Werten überein. Die anderen beiden Chats
wurden vor und nach jedem Hardwarepaket informiert. Der letzte eigene
GPU-Prozess ist beendet und der reine QA-Host über die Speicherpflege bereinigt.
X-Gameplay, Wildkämpfe, weitere Gegner, spätere Gebiete, Stereo-Dauerlast und
physische Controller sind durch diesen frühen Y-Test nicht qualifiziert.

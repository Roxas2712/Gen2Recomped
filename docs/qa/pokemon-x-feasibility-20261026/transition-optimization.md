# Gebietswechsel: Optimierung und kontrollierter Nachtest

Integration und Prüfung: **Roxas2712**, 27.10.2026, Apple M3, macOS arm64.

Die neue private Bridge enthält zwei begrenzte Änderungen:

- Bildschirm-Schnappschüsse behalten ihre zwei benötigten Batch-Versionen.
  Ein zusätzliches altes Speicherstück wird wiederverwendet, sobald kein
  anderer Leser es hält. Das vermeidet wiederholte große Allokationen und
  Freigaben auf dem Spielthread. Angezeigte Bilder bleiben unveränderlich.
- Auf dem Mac laufen kleine, bereits nativ kompilierte SIMD-Vertexpakete
  direkt auf dem Spielthread. Für diese Pakete entfällt die vollständige
  Übergabe an den Rayon-Pool samt Warten auf einen anderen Thread. Große
  Pakete und noch interpretierte Shader behalten ihre Parallelisierung.

Ein CPU-Sampling im unveränderten Stand zeigte sowohl `read_picture` →
`Arc::drop` → `free_medium`/`madvise` als auch Wartepfade über Rayons
`in_worker_cold` und `LockLatch`. Diese Befunde motivieren die Änderungen;
sie beweisen nicht, dass jede früher beobachtete Pause dieselbe Ursache hatte.
Der Sampling-Lauf mit ausführlichem Logging ist kein Geschwindigkeitsvergleich.

Die reproduzierbaren Quellpatches und Anwendungshinweise liegen in
[`tools/patches/README.md`](../../../tools/patches/README.md). Der unveränderte
Referenzstand bleibt lokal für einen Rollback erhalten. Der Launcher lädt die
neue Bridge direkt; sein Geräteschlüssel enthält den Bridge-Hash und verwirft
dadurch alte Startqualifikationen nach einem Backendwechsel.

Die Prüfung verwendet dasselbe selbst erspielte Y-QA-Schnellstandbild und
identische normale 3DS-Tasteneingaben bei 3×, Stereo aus. Reihenfolge:
Alt–Neu–Neu–Alt, vier eigene Fensterläufe mit je drei Hin-/Rückwegen
Aquarellia → Route 1 → Escissia → Route 1 → Aquarellia. Die alte Version läuft
auch am Ende erneut, damit ein wärmerer System-/Treiber-Cache nicht allein als
Verbesserung der Änderung erscheint. Die normalen Benutzerspielstände werden
nicht geladen oder verändert. Die Hardware-Sperre umfasst Vorbereitung,
Build, Testfenster und vollständige Bereinigung; die anderen beiden Chats
erhalten vor und nach dem Paket eine Nachricht.

Die Auswertung trennt Fortschritt der Emulation, beobachtete native Frame-Arbeit
und Fenster-Redraws. QA-PNG-/Schnellstandintervalle sind markiert; ihre langsamen
Frames bleiben im Bericht sichtbar, gehen aber nicht in die Verteilungswerte
ein. Ein automatisches Diagnosebild versteckt seinen auslösenden langsamen
Frame nicht. Emulationstaktung ist keine Behauptung von 60 gerenderten Spiel-FPS.
Die hier als native Frame-Arbeit ausgewertete Größe ist `worker_ms`: native
Spiel-/GPU-Ausführung und Readback sowie Leertest, Bildkopie und Audioübergabe
im Spiel-Worker. Sie ist keine isolierte Rust-CPU-Zeit und nicht direkt mit dem
älteren 2,38-ms-Professor-Mikrovergleich gleichzusetzen.

Die zehn Bridge-Tests, drei Tests für Speicherwiederverwendung/Bildschutz und
eine Bitgleichheits-/Reihenfolgeprüfung für vorbereitete und unvorbereitete
Shader an sieben Paketgrößen bestehen. Dies sind gezielte Prüfungen; es wurde
nicht die komplette Upstream-GPU-Testsammlung ausgeführt.

Der getrennte [Versuch nur mit Readback-Puffer](transition-readback-only.json)
bleibt als Vergleich erhalten. Auch dort reproduzierten die Kontrollläufe die
früheren Halbsekunden-Hänger nicht. Ein ruhiger neuer Lauf allein berechtigt
deshalb nicht zur Aussage, deren Ursache sei vollständig beseitigt.

## Ergebnis des abschließenden Vergleichs

Alle vier Fensterläufe sind erfolgreich beendet, alle sechs erwarteten
Endpunktbilder je Lauf vorhanden und die relevanten Streckenabschnitte laut
Telemetrie vollständig im aktiven Fenster gelaufen. Die neue Version wurde
damit auf sechs Hin-/Rückwegen geprüft, die Referenz auf sechs weiteren.
Die sichtbaren Endpunkte stimmen mit Escissia und Aquarellia überein:
[Escissia](transition-candidate-2-escissia-3.png),
[Aquarellia](transition-candidate-2-aquarellia-3.png).

| Lauf | Beobachtete native Arbeit: Mittel | p95 | Maximum außerhalb QA-Aufnahmen |
| --- | ---: | ---: | ---: |
| Alt 1 | 4,076 ms | 9,850 ms | 12,856 ms |
| Neu 1 | 3,559 ms | 8,559 ms | 10,658 ms |
| Neu 2 | 4,018 ms | 9,480 ms | 12,937 ms |
| Alt 2 | 4,065 ms | 9,809 ms | 12,190 ms |

Über die beobachteten abgeschlossenen Frames gewichtet sinkt die mittlere
native Arbeit von 4,070 auf 3,784 ms, rund **7,0 %**. Beide neuen Läufe bleiben
außerhalb der markierten QA-Intervalle unter 13 ms; die Emulation läuft in den
Streckenabschnitten mit ungefähr 59,75–59,83 Hz. Das ist mehr Zeitreserve,
keine entsprechende Erhöhung der Spielbildrate. Ein 91,65-ms-Frame im ersten
neuen Lauf liegt im markierten PNG-Aufnahmeintervall und bleibt als solcher im
Bericht erhalten.

Die früher gemessenen Pausen von 312–569 ms sind in diesem Nachtest **nicht
wieder aufgetreten**. Da sie auch die unveränderte Referenz nicht reproduziert,
ist ihre vollständige kausale Behebung durch die Änderungen **nicht bewiesen**.
Die Aussage ist daher: Die geprüfte Strecke läuft im Nachtest ohne diese großen
Aussetzer, mit etwas weniger nativer Arbeit. Eine pauschale Freigabe aller
Gebiete, erstmaliger Shader-/Treiber-Caches, Hintergrundlasten, X oder Stereo
ergibt sich daraus nicht. Spätere Kämpfe wurden nach dieser Änderung nicht
erneut qualifiziert.

[Vollständiger Messbericht](transition-optimized.json),
[identische Eingaben](transition-input.json) und komprimierte Rohdaten:
[Alt 1](transition-baseline-1-frames.csv.gz),
[Neu 1](transition-candidate-1-frames.csv.gz),
[Neu 2](transition-candidate-2-frames.csv.gz),
[Alt 2](transition-baseline-2-frames.csv.gz).
Der Auswerter ist `tools/pokemon_xy_transition_report.py`.

[Bridge-Tests](native-bridge-tests.log),
[Puffer-Tests](native-readback-tests.log) und
[Bitgleichheit](native-handoff-tests.log) sind gesichert; lokale Benutzerpfade
wurden durch Platzhalter ersetzt. Nach Abschluss stimmen die vier normalen
Benutzer-Savedateien weiterhin mit den vorher aufgenommenen SHA-256-Werten
überein. Eigene Test-/Buildkinder sind beendet, der reine QA-Host ist bereinigt
und beide anderen Chats haben die Hardware-Freigabe erhalten.

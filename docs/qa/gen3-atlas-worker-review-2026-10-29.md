# Atlas-Worker: budgetierte Veröffentlichung und Vergleichsstatus

Dieser historische Zwischenstand dokumentiert die zunächst blockierte Prüfung.
Der anschließend vollständig bestandene Vergleich und die aktuelle Freigabe
stehen im [abschließenden Nachweis](gen3-atlas-worker-qualified-2026-10-29.md).
Die folgenden Abbrüche und offenen Punkte beschreiben den damaligen Stand.

## Behobene Arbeit außerhalb des Budgets

Der zentrale Pool-Callback hat bisher die gesamte Upload-Coroutine synchron
bis zum Ende ausgeführt. Er nimmt jetzt ausschließlich CPU-Ergebnisse an.
Der vorhandene Stream lädt höchstens eine Textur je Schritt hoch. Ein erst
halb hochgeladener Atlas bleibt außerhalb des residenten Caches.
Ein ausdrücklich benötigter `get()` behält seine sofortige Fertigstellung.
Ein einzelner nativer Grafikaufruf kann weiterhin länger als die angebotene
Zeitscheibe dauern; eine feste Obergrenze für GPU-Aufrufe wird nicht behauptet.

Zwischen den Schritten können Mods Paletten/Daten, öffentliche Coroutines
oder die Worker-Zulassung ändern. Ein bis zur Veröffentlichung erhaltener
Quellvalidator erkennt das. Unveröffentlichte Ressourcen werden freigegeben,
und die bestehende Coroutine baut über den lebenden nativen Besitzer weiter.
Auch nach Annahme eines CPU-Ergebnisses installierte Mod-Wrapper bleiben erhalten.

## Bestandene Prüfungen

Der Laufzeitstand ist `341a8976`; `1482ea77` ergänzt ausschließlich QA-Werkzeuge
und den reproduzierbaren Grafikhost. Die gezielten CPU-Gruppen bestehen:
Worker867, Pixel1748, Ressourcen526, Paletten602, Planner55, Alpha/Tiefe69,
FRLG-Credits76 und Walker-Transfer667. Die gezielten Tests wurden vor dem
Commit auf derselben anschließend eingecheckten Laufzeit ausgeführt.

Der echte LÖVE-11.5-Threadhost besteht1033 dynamische Prüfungen, vier
Kanal-Neustarts und den ByteData-Rundlauf. Auf LOW entstehen über fünf
Editionen327680 identische RGBA-Bytes, ohne Grafikmodul im Worker.

Der öffentliche Host `tools/native-atlas/worker-host` besteht mit echtem
LÖVE12 auf Metal275 und OpenGL280 dynamische Prüfungen: fünf Editionen,
reale Worker, gestaffelte Texturen und tatsächliche Textur-Readbacks gegen
die native Pixelreferenz. Späte Quelldatenänderungen und Abbrüche nach dem
ersten Upload geben Ressourcen frei und veröffentlichen keinen veralteten Atlas.
Die Anzahl dynamischer Warteprüfungen schwankt mit der Thread-Laufzeit.

Der zusätzliche Volltest wurde an der vorgeschriebenen freien Reserve von
20GiB angehalten. Eine Fortsetzung wurde ebenfalls durch diese Grenze
beendet. Bis dahin wurde kein Prüffehler gemeldet. Das ist kein bestandener
Volltest; die Gesamtqualifikation muss noch beendet werden.

## Tatsächlich gleiche Fensterbedingungen

Allein ein unsichtbares Fenster oder `SDL_SetWindowFocusable(false)` hat auf
Cocoa nicht zuverlässig den initialen Fokuszustand abgegeben. Der optionale
QA-Schalter `--unfocused-sdl3` verwendet eine echte native Ein-/Ausblendung
nach dem Abschalten der Fokussierbarkeit und mit deaktivierter Aktivierung.
Vier eigenständige native Vorprüfungen erreichen dadurch durchgehend `false`.
`love.window.hasFocus()` und die Frame-Pacing-Abfragen werden nicht ersetzt.
Die Abfrage jedes echten Messframes muss denselben Zustand bestätigen.
Das native Verhalten ist ausschließlich ein QA-Werkzeug.

`--compact-host` verwendet einen Git-Teilbaum mit identischen Laufzeitdateien.
Nur unbenutzte Plattformpakete, Mods, Dokumentation und CI-Dateien werden im
privaten Source-Field-Host ausgelassen. Die Variante ist für die Mod-freie
Atlas-Brücke begrenzt; Engine, Daten und Grafikressourcen bleiben bytegleich.
Der Export läuft weiterhin über `qa_extract_archive`, ohne Zwischenarchiv.

## Vorab festgelegter Vergleich und offener Blocker

Aus–An–An–Aus: gleicher Commit, vier frische Emerald-Imports, jeweils mindestens
60 reale Sekunden, tatsächliche Route101→Oldale→Route103-Bewegung, HIGH,
Cap160, VSync aus, Hintergrundlimit aus und durchgehend tatsächlicher Fokusfalse.
Die Hauptthread-Abschnitte Prefetch, Stream-Schritt und Pool-Auslieferung werden
getrennt und ohne gegenseitige Überlappung erfasst. Die Snapshot-/Auslieferungs-
kosten zählen damit zum Worker-Pfad; die Pixel-Konstruktoren werden nicht ersetzt.

Vor Beginn festgelegt: mindestens20Prozent weniger Hauptthread-Arbeit für
Atlasvorbereitung in jedem Paar, höchstens5Prozent mittlere Frame-Regression
je Paar und höchstens10Prozent Verschlechterung der gemittelten Nahtmaxima.
Jeder ON-Lauf muss einen tatsächlich verwendeten Worker-Atlas veröffentlichen.
Diese begrenzten Kriterien sind keine vollständige Spiel-, Handheld-, Energie-
oder60-FPS-Freigabe.

Die neuen ABBA-Anläufe wurden wegen der Speicherreserve beendet, bevor eine
Messung freigegeben wurde. Es existiert kein akzeptierter neuer Zeitvergleich.
Alte Fokus-Vergleiche bleiben abgewiesen. Aus den Grafik-/Korrektheitsprüfungen
wird kein Geschwindigkeitsgewinn abgeleitet. Ohne vollständigen Vergleich und
abgeschlossene Regressionen bleibt der Merge gesperrt.

[Reduzierte Korrektheitsnachweise](gen3-atlas-worker-2026-10-29/correctness.json)
und [vorab registrierte Vergleichskriterien](gen3-atlas-worker-2026-10-29/pending-comparison.json)
enthalten keine ROMs, privaten Mods, Konten oder lokalen Dateipfade.

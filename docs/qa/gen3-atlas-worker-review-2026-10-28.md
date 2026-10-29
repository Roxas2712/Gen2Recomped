# Atlas-Worker: erneute Prüfung am 28. Oktober 2026

Der PR bleibt ein Entwurf. Ein belastbarer Geschwindigkeitsgewinn ist weiterhin
nicht nachgewiesen; die bestehende Integrationssperre wird nicht aufgehoben.
Die übrigen 16 geprüften Entwürfe sind davon unabhängig in `main` integriert.

## Korrekturen und Prüfgrenzen

Direkter `get()`-Bedarf startet keinen sofort wieder abgebrochenen neuen
Worker mehr. Bereits explizit vorab gestartete Jobs können weiterhin bei
sofortigem Bedarf abgebrochen werden. Wartende Jobs prüfen pro Frame Zulassung
und Frist; vollständige kopierte Quellwerte werden vor Verarbeitung der
Antwort weiterhin validiert. Die bisherige Pixelberechnung bleibt erhalten.
Die fokussierten Tests umfassen 851 Worker-, 1748 Pixel-, 526 Ressourcen- und
602 Palettenprüfungen vor der abschließenden main-Integration. Nach Integration von `main`
`a2759171` bestehen diese vier Gruppen erneut sowie Shader-Planung 55,
Alpha-/Tiefenvertrag 69, FRLG-Credits 76 und Walker-Transfer 667.
Der dabei geprüfte Laufzeitkopf ist `69a7a230`; die anschließenden Änderungen
betreffen ausschließlich diese Dokumentation und reduzierte Nachweise.

Zusätzlich besteht der echte LÖVE-11.5-Threadhost mit 1913 dynamischen Checks,
vier Kanal-Neustarts, ByteData-Rundlauf und einem LOW-Worker. Alle fünf
GBA-Editionen liefern 327680 identische RGBA-Bytes; im Worker wird kein
Grafikmodul geladen. [Korrektheitsnachweis](gen3-atlas-worker-2026-10-28/current-main-correctness.json).

Der Messstarter unterstützt unsichtbare native Fenster und verlangt unveränderten
tatsächlichen Fensterfokus. Fokuswechsel erhalten die vollständigen Messdaten
mit einer expliziten Ablehnung. Git-Exporte verwenden begrenzte Pipes.
Zeitweise von NPCs belegte Wegabschnitte werden mit nativer Kollision begrenzt
neu geplant, ohne Figurenpositionen oder Spielregeln zu überschreiben.

## Erneute echte Emerald-Messung

Der gleiche Quellkopf `74e48eadbe82cf1ecac4b3d46226c6453abf9ba7` läuft auf
LÖVE 12/Metal mit frischem lokalem Import und getrennten QA-Profilen.
Native Eingaben überqueren Route 101 → Oldale → Route 103. HIGH, Cap 160,
VSync aus und deaktiviertes Hintergrundlimit gelten für beide 60-Sekunden-Läufe.
Die App erhält zusätzlich `SDL_MAC_BACKGROUND_APP=1`; die Fokusabfrage selbst
wird nicht ersetzt.

| Worker | Mittlerer Frame (ms) | Erste Naht (ms) | Zweite Naht (ms) | Tatsächlicher Fokus |
| --- | ---: | ---: | ---: | --- |
| Aus | 8,810 | 183,876 | 157,356 | durchgehend false |
| An | 6,405 | 154,753 | 154,795 | durchgehend true |

Die genaue mittlere ON-Zeit steht im JSON-Nachweis; Tabellenwerte sind gerundet.
Beide Einzelläufe bestehen ihre Funktionsprüfung. Der Controller verwirft den
Vergleich wegen unterschiedlicher Fokussituationen und startet die übrigen
ABBA-Fälle nicht. Diese Zahlen belegen deshalb keinen kausalen Vorteil.
Der ON-Lauf überträgt tatsächlich zwei Jobs, bricht einen ab und veröffentlicht
einen Atlas; die abschließenden Cacheeinträge weisen einen nativen und einen
Worker-Atlas aus. Keine Spielerdaten oder ROM-Inhalte werden veröffentlicht.

Der normale native Renderer besitzt einen anderen Atlas-Erzeuger. Dieser PR
betrifft die Source-Field-Brücke. Ein leerer Schaltervergleich im anderen
Renderer wäre kein Nachweis. Außerdem veröffentlicht der aktuelle Callback
fertige Worker-Pixel weiterhin synchron bis zum Ende des Upload-Coroutines;
dessen Anteil an Frame-Spitzen bleibt zu untersuchen. Weitere Änderungen daran
benötigen zusätzliche Besitz-, Änderungs- und Veröffentlichungsprüfungen.

[Reduzierter vollständiger Vergleichsnachweis](gen3-atlas-worker-2026-10-28/rejected-focus-comparison.json)
enthält alle relevanten Zeiten, tatsächliche Fokuszustände, native Nahtnachweise
und Workerzähler ohne lokale Pfade oder private Inhalte. Die historischen
Nachweise vom 27. Oktober bleiben unverändert erhalten.

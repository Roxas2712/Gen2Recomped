# Atlas-Worker: qualifizierter Vergleich vom 29. Oktober 2026

Die vorab registrierten Leistungsgrenzen sind im vollständigen ABBA-Vergleich
erfüllt. Gemessen wurde `3b06b0bf80461fe3042f541b44fa7be2c1a5983d`, einschließlich
Fork-main `dc691d6269e85cb7957d106f4de5e3e52fc04ff0`. Der Runtime-Fix ist seit
`341a8976` unverändert; der spätere Schlusscommit ergänzt ausschließlich Nachweise.

## Identische Bedingungen

Vier getrennte frisch importierte Emerald-QA-Profile, Aus–An–An–Aus, jeweils
mindestens 60 reale Sekunden auf Apple M2, LÖVE12/Metal, 1024×768 logisch und
2048×1536 Pixel. HIGH, Cap 160, VSync 0 und deaktiviertes Hintergrundlimit sind
fest. Alle Abfragen bleiben native Funktionen; eine echte nicht fokussierbare
Fensterein-/ausblendung gibt den Fokus ab. Jeder gemessene Frame meldet tatsächlich
Fokus false und HIGH. Keine Mod ist geladen. Alle vier Läufe überqueren mit nativen
Eingaben dieselben 33 beziehungsweise 20 Zellen Route 101→Oldale→Route 103.

Die eigenen CPU-/GPU-Prüfungen waren vor der Messung beendet. Getrennte
Kindprozesse halten Anzahl und Lebensdauer ihrer QA-Wächter vergleichbar.
Der kompakte Git-Export enthält identische Engine-, Daten- und Grafikdateien;
nur unbenutzte Plattformpakete, Mods, Dokumentation und CI-Dateien fehlen.
Zwischen den Fällen werden reine Hostkopien über den vorhandenen Helfer gesichert
und bereinigt. Mods, ROM-Originale und Spielstände sind keine Bereinigungsziele.

## Ergebnis und vorher festgelegte Grenzen

Die gemessene Hauptthread-Wallzeit ist die Summe der nicht überlappenden
Abschnitte Prefetch, Stream-Schritt und Pool-Auslieferung im jeweiligen
60-Sekunden-Intervall. Sie zählt Snapshot, Kanal-Auslieferung und Grafikallokation
mit; Pixel-Konstruktoren oder Rückgaben werden durch die Messadapter nicht ersetzt.

| Lauf | Atlas-Hauptthread insgesamt (ms) | Mittlerer Frame (ms) | Größter Stream-Schritt je Frame (ms) | Nahtmaxima 1 / 2 (ms) |
| --- | ---: | ---: | ---: | ---: |
| off-a | 86.332 | 8.477 | 7.271 | 156.079 / 109.892 |
| on-a | 37.693 | 8.505 | 1.503 | 130.653 / 125.126 |
| on-b | 28.274 | 8.499 | 1.328 | 123.462 / 120.796 |
| off-b | 95.256 | 8.500 | 6.616 | 134.643 / 138.823 |

Die Hauptthread-Zeit sinkt im ersten Paar um 56,34 Prozent, im zweiten um 70,32 Prozent.
Die mittlere Framezeit verändert sich um +0,328 Prozent beziehungsweise −0,013 Prozent.
Die gemittelten Nahtmaxima verschlechtern sich auf keiner der beiden Strecken.
Die ON-Läufe veröffentlichen jeweils tatsächlich einen Worker-Atlas und benutzen
ihn im abschließenden Cache; OFF startet keinen Atlas-Worker. Kein Workerfehler
tritt auf. Der zunächst unmittelbar benötigte Atlas wird bei ON weiterhin
synchron fertiggestellt; der vorab gestartete CPU-Job wird dabei abgebrochen.

Vor der ersten Messung registriert und unverändert ausgewertet: mindestens
20 Prozent weniger Hauptthread-Arbeit je Paar, höchstens 5 Prozent Verschlechterung
der mittleren Framezeit je Paar und höchstens 10 Prozent Verschlechterung der
gemittelten Nahtmaxima. Alle Kriterien bestehen. Alle vier Fälle sind enthalten;
die früher abgewiesenen Fokusläufe und wegen Speicherreserve abgebrochenen
Anläufe bleiben getrennt als ungültige Zwischenstände dokumentiert.

## Korrektheit und praktische Grenzen

32 betroffene CPU-Gruppen bestehen am gleichen Quellkopf einschließlich Worker 867,
Pixel 1748, Ressourcen 526 und Paletten 602 sowie der neueren main-Verträge.
Der öffentliche echte Grafikhost besteht auf Metal 400 und OpenGL 226 dynamische
Checks über fünf Editionen, reale Threads, Textur-Readbacks, Abbruch und späte
Quelldatenänderungen. Quell- und Eingabefingerprints bleiben unverändert.

Der gemessene Kopf besteht in der tatsächlichen GitHub-Merge-Komposition
`e4c2251` mit main `dc691d626` alle 956/956 Engine-Suites, SDK 4/4 und alle
verfügbaren ROM-freien Tiers. Alle 74 aktiven Kopfprüfungen bestehen; ein
nicht betroffener Plattform-Build ist regulär übersprungen. Der frühere
935/935-Nachweis bleibt nach seinem eigenen Quellstand getrennt erfasst.

Der Vorteil betrifft die CPU-Vorbereitung der Source-Field-Atlasbrücke und die
budgetierte Veröffentlichung. Der gewöhnliche native Renderer hat einen anderen
Atlas-Erzeuger. Daraus folgt weder eine allgemeine FPS-Steigerung noch eine
vollständige Spiel-, Handheld- oder Energiefreigabe. Die Ergebnisse sind
instrumentierte Present-Intervalle und Hauptthread-Wallzeiten auf einem Gerät;
GPU-Queue-Zeit ist keine durch einen Fence gemessene GPU-Ausführungsdauer.
Ein einzelner nativer Upload kann die angebotene Zeitscheibe weiterhin überschreiten.
Ein ausdrücklich benötigter `get()` bleibt synchron. Der bestehende Schalter
`POKEPORT_PERF=atlasWorker=0` erhält den nativen Coroutine-Pfad.

## Reproduktion

Mit eigenem authentischem Emerald-Import und einer LÖVE12/SDL3-Laufzeit für
jeden Fall einen neuen Ausgabeordner verwenden. Dieselben Optionen nacheinander
mit `--perf atlasWorker=0`, `1`, `1`, `0` ausführen:

```sh
python3 tools/check_performance_baseline.py \
  --love "$LOVE12" --lua "$LUAJIT" --emerald "$EMERALD" \
  --out "$FRESH_QA_OUTPUT" --scene emerald-route101-103 --measure \
  --variant idle-on --seconds 60 --backend metal --fps-cap 160 \
  --atlas-bridge --compact-host --hidden --stable-focus \
  --unfocused-sdl3 "$SDL3_LIBRARY" --perf atlasWorker=0
```

Die Platzhalter bezeichnen lokale Eingaben; keine ROM-Datei gehört in den PR.
Die normale Importprüfung, mindestens 20 GiB freie Reserve, gesperrte aktive
Eingaben sowie Copy-/Profilbudgets bleiben aktiv. Hauptthread-Zeit berechnen:
Summe `avgMsPerFrame × measurement.frames` der drei oben genannten Abschnitte.
Die Paare sind AusA/AnA und AusB/AnB. Tatsächlichen Fokus, HIGH, Quellkopf,
Grafikgerät, Auflösung, Worker-Publikation und native Nahtnachweise in jedem
Fall prüfen. Ein Prozessende mit Status0 allein ist kein Leistungsnachweis.

[Alle vier Messfälle und registrierten Kriterien](gen3-atlas-worker-2026-10-29/qualified-abba.json)
und [Korrektheitsnachweise](gen3-atlas-worker-2026-10-29/qualified-validation.json)
enthalten keine lokalen Dateipfade, privaten Mods, Konten oder ROM-Inhalte.

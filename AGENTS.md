# Hinweise zur lokalen QA

## Urheberschaft und Lizenz dieses Forks
Öffentlich ausschließlich das Pseudonym **Roxas2712** verwenden, auch für
Credits, Lizenztexte, PR-Texte und neue Git-Author-/Committer-Metadaten.
Keinen Klarnamen aus lokalen Pfaden, Konten oder älteren Commits übernehmen.
Vor neuen Beiträgen `NOTICE.md` und `LICENSE-ROXAS2712.md` lesen. Roxas2712 behält seine eigenen Rechte; Cedric / UNDERdecoded erhält für
angebotene PR-Beiträge die dort beschriebene Erlaubnis mit Credits.
Bestehende Rechte und Lizenzen anderer Autoren nicht überschreiben oder
nachträglich einschränken. Bei neuen Upstream-PRs auf diese Beitragslizenz
hinweisen und sicherstellen, dass die Bedingungen mit den bereits geltenden
Verpflichtungen vereinbar sind. Keine fremden Änderungen oder ganze Dateien
allein wegen eines Commit-Autors als Eigentum von Roxas2712 deklarieren.

## Vollständige automatische QA-Speicherpflege
Alle neuen Teststarter verwenden `tools/qa_storage.py`: Eingaben vor der ersten Bereinigung mit `qa_source` pinnen, eigene eingefrorene Kopien vor dem Schreiben mit `qa_copy`, QA-Profile mit `qa_profile` und Ausgaben mit `qa_cache` sperren. QA-Prozesse und Kopierkommandos mit `qa_run`/`qa_popen` starten. Die freie Reserve beträgt jetzt 20 GiB. Ein globales 4-GiB-/24-Stunden-Budget gilt gemeinsam für alte und zusätzliche Testkopien. Der lokale LaunchAgent ergänzt alle 15 Minuten die sichere Entdeckung älterer Layouts. Tatsächliche Quell-Checkouts, Modelle, ROM-Originale und Spielstände erhalten; Kopienstände vor Entfernen mit `qa_preserved.py` dauerhaft sichern. Keine eigenen pauschalen `rm`-/Altersbereinigungen ergänzen. Details und Regressionen: `docs/QA-STORAGE.md`, `python3 -m unittest discover -s tests -p 'qa*storage*test.py'`.


## Reine Testkopien nach Testende bereinigen
Reine CPU-/GPU-/Story-/Vergleichstests registrieren Hosts und Referenzkopien mit
`qa_copy(path, ephemeral=True)`. Nach Testende, auch bei Fehlern, werden deren
Code-/Modellbytes dauerhaft gesichert und die Kopien gezielt entfernt. Andere
Leser, lebende Kindprozesse, `.qa-keep`, ROMs und Spielstände bleiben geschützt.
Logs und Nachweise bleiben außerhalb der Kopie. Pakete für spätere Build-/
Veröffentlichungsschritte verwenden weiter `qa_copy(path)` und `qa_source` für
aktive Eingaben. Keine Teststarter mit eigener 8-GiB-Reserve ergänzen: 20 GiB
beibehalten. Details: `docs/QA-STORAGE.md`.

Zum Fortsetzen eines bereits bereinigten Tests `qa_restore_copy(host)` verwenden:
Es stellt den exakt gesicherten Host bei Bedarf wieder her, erhält vorhandene
Spielstände und verweigert das Überschreiben neuerer Dateien. Anschließend
bleibt der Host als gemeinsam lesbare Eingabe gesperrt und wird nach dem letzten
Leser wieder bereinigt. Veröffentlichungs-/Buildpakete bleiben davon getrennt.

Teststarter außerhalb der versionierten Werkzeuge laden bevorzugt den installierten
Helfer `~/.local/lib/origami-qa-storage/active-tools`, damit ein Wechsel des
Spielzweigs die Speicherregeln nicht zurücksetzt. Vor dem ersten `qa_*`-Aufruf
`qa_storage._storage = qa_storage.Storage(projektwurzel)` mit `atexit`-Freigabe
initialisieren; als Projektwurzel niemals das Verzeichnis des installierten
Helfers verwenden. Bestehende Starter mit dieser Initialisierung beibehalten.

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

LÖVE-Testcachepflege erfolgt über `qa_love_storage.py` im installierten Helfer,
nicht durch Löschen ganzer Profile. Nur die dokumentierten `data/generated`-/
`assets/generated`-Pfade sind vorgesehen; auch dort Modelle, Quellordner, Saves
und ROMs erhalten. Neue private Profile vor Nutzung mit `qa_source` pinnen.
Einmalige zu entfernende Cachebytes werden im bestehenden Quellarchiv gesichert.


## Produzenten begrenzen statt Zwischenarchive anhäufen

Archivierte Referenzen mit `qa_extract_archive(git_dir, revision, destination)`
über eine Pipe entpacken; kein `baseline.tar` pro Lauf schreiben. Alte bekannte
QA-Zwischenarchive werden mit ihren einzelnen Quell-/Modellbytes im dauerhaften
Archiv dedupliziert, mit Wiederherstellungsnachweis, bevor sie entfernt werden.

`qa_cache` begrenzt einen Ausgabeordner während des eigenen Kindes auf 4 GiB.
`qa_limit_output(path, bytes)` ergänzt weitere reine Schreibbudgets; diese
Funktion erteilt keine Löschberechtigung. Die echte Benutzerumgebung erzwingt
mindestens 20 GiB frei, auch wenn ein alter Starter 8 GiB anfordert. Ein Budget-
verstoß stoppt nur den neu gestarteten eigenen Prozessbaum mit sichtbarem Fehler.
Kontrolle vor Start und während `qa_run`/`qa_popen`, maximal zwei Sekunden zwischen
Budgetmessungen; keine harte Dateisystemquote, ein Schreibstoß kann überschießen.

X/Y-Backend: vor dem Build `qa_build_storage.prepare(storage, work, sha256)`
unter `session.lock`, maximal 2 GiB je ROM-Fingerprint / 4 GiB zusammen. Nach
erfolgreichem Link und zusätzlich alle 15 Minuten nur bekannte `codeNNN.o`-/
`entries.o`-Zwischenprodukte mit vorhandener C-Quelle entfernen. Laufende Builds,
`.qa-keep`, C-/Headerquellen, Modelle, ROMs, fertige Bibliotheken und Spielstände
bleiben erhalten. Ein neuer Fingerprint über dem Budget wird abgelehnt, statt
ungeprüft alte Quellen oder fertige Bibliotheken zu entfernen. Direkte Aufrufe
an den Helfern vorbei haben keine laufende Budgetkontrolle.

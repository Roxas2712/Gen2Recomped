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

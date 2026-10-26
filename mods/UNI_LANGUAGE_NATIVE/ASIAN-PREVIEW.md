# Asiatische Gen2-Profile – Prüfumfang für Release 1.7.0

Die 508 zuvor fehlenden Kristall-Einträge sind geschlossen: **356 zusätzliche ROM-Zuordnungen und 152 ausdrücklich eigene Übersetzungen für den US-Spielablauf**. Kein erfasster Dialog- oder Systemtexteintrag ist mehr unbesetzt. Die Mod bleibt ein Sprachaufsatz auf der US-Basis; regionale Spielfunktionen werden nicht hinzugefügt.

| Profil | Dialoge | Benannte Texte | Eigene Kompatibilitätstexte | SHA-1 der Sprach-ROM |
|---|---:|---:|---:|---|
| gold / ko | 3044/3044 | 889/889 | 17 | `c0ff3999e1093e1af59ef3eea3f1bfd7c1f18a65` |
| silver / ko | 3044/3044 | 889/889 | 17 | `cb22d7e03a74dc3a563fde6be8626626b2b392e7` |
| crystal / ja | 4003/4003 | 1011/1011 | 152 | `95127b901bbce2407daf43cce9f45d4c27ef635d` |

Menüs und Grafikbeschriftungen: native Titel, Rucksack samt Taschenreitern, Trainerkarte, Arenaleiter, Pokédex, PokéCom, Diplom und Center-/Shop-Fassaden. Die festen Engine-Menüs und Port-Abspannrollen sind separat übersetzt. Kachelpositionen, koreanische Zeilenhöhe, japanische Lautzeichen, Unicode-Laufschrift und vertauschte Textparameter sind im Mod angepasst; die Engine bleibt unverändert. Die asiatische Teamliste zeigt vier Einträge gleichzeitig und scrollt zu allen sechs Pokémon; Namen, Status, Level und KP bleiben erhalten. PC- und Auswahlrahmen sind an die größere Schrift angepasst.

Je Edition sind 1.060 tatsächliche Gen2-UI-Quellschlüssel geprüft. Ausnahmen sind ausdrücklich benannte Zahlenformate, Einheiten, Glyphenmakros und Hardwarekürzel. Originale Aufschriften wie THE END und CONGRATULATIONS sowie Namen der Port-Mitwirkenden bleiben erhalten. Dies ist Textabdeckung, keine Behauptung, jeden Ereigniszweig durchgespielt zu haben.

## Echte Spieltests

Center-Heilung und Abschied, Ladenkauf mit korrektem Betrag und Inventar, Wildkampf bis zum Sieg, Namenseingabe und Speichern/Laden, das reguläre Intro, Optionsuntermenüs, Team/Status, Taschen, PC, Trainerkarte, PokéCom und Pokédex wurden in allen drei Editionen ausgeführt. Zusätzlich wurden Kristalls Ei-Geschenk und Brief-Tausch über die echten US-Kartenskripte gespielt. Ihre japanischen Texte sind eigene Kompatibilitätsübersetzungen, keine angeblichen japanischen Originaldialoge.

Native Titel und Diplom sowie der echte Port-Abspann wurden gerendert. Der Abspann wurde zwischen Bildaufnahmen beschleunigt; es wurde dafür kein neuer Dialog oder Abspanntext in den Test eingespeist. Screenshots und Protokolle liegen privat unter `build/asian-gen2/live/`, die Ingame-Dokumentation unter `build/asian-gen2/Pruefbericht.html`.

85 Python-Tests und 18 Lua-Testgruppen bestanden; alle Mod-Lua-Dateien wurden auf Syntax geprüft. Binär-/Einheitstests sind keine Übersetzungsbelege. Kalter Import und Cache-Start liefern identische Nutzdaten; der Wechsel zurück zu Englisch erhält lesbare asiatische Spielernamen.

| Profil | Kalt | Cache | Lua-Heap nativ / Englisch |
|---|---:|---:|---:|
| gold ko | 201 ms | 119 ms | 38.4 / 31.1 MiB |
| silver ko | 317 ms | 140 ms | 38.3 / 31.2 MiB |
| crystal ja | 273 ms | 154 ms | 41.8 / 32.9 MiB |

Die Performancewerte stammen aus den vorherigen Entwicklungsprüfungen; sie sind kein neuer Release-Benchmark. Messumfang: je 360 Update-/Draw-Frames in einer Szene auf diesem Mac mit VSync. Andere Anwendungen liefen parallel; insbesondere enthält Gold/Englisch einen Draw-Ausreißer von etwa einer Sekunde. Kristall nativ und Englisch hatten zudem deutlich unterschiedliche Frame-Ausgabezeiten (ca. 0,8 gegenüber 6,8 Sekunden für 360 Frames). Daraus wird kein Geschwindigkeitsvergleich abgeleitet. Die Messung isoliert keinen Übersetzungs-Overhead. Keine Messung des gesamten Prozessspeichers, kein Benchmark aller Szenen und kein Nachweis eines generell fehlenden Overheads. Details, Grenzen und Dateiprüfsummen stehen in ASIAN-QA.json.

Kein vollständiger Spieldurchlauf und kein Link-/Mobile-Test. Eigene Übersetzungen sind nicht als muttersprachlich lektoriert ausgewiesen. Die übergreifenden Paketprüfungen stehen separat in MERGE-QA.json.

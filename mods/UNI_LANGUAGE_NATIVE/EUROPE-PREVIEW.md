# Europäische Sprachprofile · 1.4.3-europe-preview.5

Ausgangspunkt ist der unveränderte Release 1.4.2 (Commit 5843925).
Die parallele PT-BR-Entwicklung ist in dieser separaten Arbeitskopie nicht enthalten.
Diese Preview ersetzt keine abgeschlossene Veröffentlichung mit vollständigem Spieldurchlauf.

## Integriert

| Edition | Neue Sprachen | Dialogeinträge je Profil |
|---|---|---|
| Rot | Spanisch | 2.595 |
| Gelb | Spanisch | 2.710 |
| Gold | Spanisch, Französisch, Italienisch | 4.331 / 4.362 / 4.362 |
| Silber | Spanisch, Französisch | 4.331 / 4.362 |
| Kristall | Spanisch, Italienisch | 5.523 / 4.863 |
| Feuerrot | Spanisch, Italienisch | 9.063 ROM-Texte + 3 regionale Hilfseinträge |
| Blattgrün | Spanisch, Französisch | 9.063 ROM-Texte + 3 regionale Hilfseinträge |

Smaragd FR/IT/ES war bereits enthalten. Damit sind alle 16 bereitgestellten
Sprach-ROMs berücksichtigt: 13 neue und drei bestehende europäische Profile.
Zusammen mit Deutsch sind 27 zusätzliche Sprach-ROM-Profile registriert.
Englisch bleibt die jeweilige US-Basis. Die neun Sprachen der Mod-Oberfläche
sind davon unabhängig.

Für GB/GBC enthalten die Profile Dialogrezepte, Schrift, Pokémon-, Attacken-,
Item-, Trainerklassen- und Typnamen. Gen2 ergänzt Attacken-/Itembeschreibungen,
495 bzw. 541 einzelne Trainernamen, 95 bzw. 96 Ortsnamen und 251 Pokédex-Einträge.
Die 889 bzw. 1.011 benannten Gen2-Systemtexte sind vollständig zugeordnet.
1.520 ergänzende UI-Schlüssel pro Sprache decken die vom Recompiler verfassten
Menüs, Statusseiten, Kampfmeldungen sowie PC-, Pokécom-, Einstellungs-,
Welt-, Skript- und Link-Texte ab. Alle 1.520 Einträge wurden für Spanisch,
Französisch und Italienisch durch die KI sprachlich geprüft und überarbeitet.
Das ist ein vollständiger KI-Lektoratsdurchgang des ergänzenden Katalogs,
keine unabhängige muttersprachliche Abnahme. Die ROM-Dialoge werden
weiterhin direkt aus der jeweiligen Handelsfassung gelesen.
Italienisches Kristall enthält im Original leere, ungenutzte Mobiladapter-Texte;
deshalb unterscheiden sich Textzahlen und Inhalt zwischen den Regionen.
Metrische Pokédex-Werte ergänzen ausschließlich Anzeigefelder; die ursprünglichen
US-Gewichte und alle Kampfwerte bleiben erhalten.

Die neuen Feuerrot-/Blattgrün-Profile wurden gegen vier byteidentisch
rekonstruierte Handelsfassungen abgeglichen. Ihre Text-, Grafik- und Weltprofile
werden aus geprüften ELF-Symbolen und Tabellenstrukturen abgeleitet.
GB/GBC verwenden exakte ROM-Prüfsummen, rekonstruierte Symboltabellen,
Map-/Event-/Skript-Vergleiche und abgeglichene Textbank-Grenzen.
Das ist eine Prüfung der zugeordneten Daten, kein Beweis für jedes Spielereignis.

## Menütexte und Grafiken in Preview 3

Alle neun neuen GB/GBC-Profile verwenden den vollständigen ergänzenden UI-Katalog.
Die ROM-internen Textkürzel werden ebenfalls sprachgerecht expandiert:
MT/CT und ENTREN./DRESSEUR/ALLEN. statt der englischen Platzhalter.
Formatfelder, Steuerzeichen und die Breiten kritischer Status-/Trainerkartenfelder
werden geprüft. Zusammengesetzte printf-Ausgaben behalten Namen und Zahlen.
Typnamen und Statuskürzel werden über die Datenregister übersetzt.

Gold/Silber verwenden je 79, Kristall je 85 Grafikrezepte: Schrift,
Titelanimationen, Pokédex, Beutel und Taschenbeschriftungen, Pokécom, Trainerkarte,
PC, Kampf-/Statusrahmen, Namenseingabe, Urkunde, Abspann und 28 bzw. 36 Weltatlanten.
Spanisches Gelb ergänzt die eigenen Titel-Tilemaps; Rot/Gelb enthalten auch
lokalisierte Weltschilder. Sprachneutrale Originalgrafiken werden weiterverwendet.
Kristalls regionale Icognito-Wandzeichen erhalten eigene visuelle Metatiles;
Karten-Block-IDs und Kollisionen bleiben unverändert. Die Namenseingabe
enthält die sprachspezifischen Akzentzeichen bei gleicher Tastaturgeometrie.

339 Menü-, Titel-, Urkunden- und Abspannbilder aller sieben Gen2-Profile wurden
pixelweise gegen eine unabhängige direkte Extraktion aus der jeweiligen ROM geprüft, einschließlich
Transparenz. Die Laufzeittests öffnen die tatsächlichen Menüs und vergleichen
die Kollisionstabellen mit der Basis. Entwicklungsbilder bleiben privat.

## Lektorat und zusätzliche Spieltests

Die Quelltextprüfung erfasst 1.499 statische Engine-Schlüssel einschließlich
zusammengesetzter Lua-Literale. Kein erfasster Schlüssel fehlt im Katalog.
Der zusätzliche Bestand enthält unter anderem dynamisch verwendete Radiotitel.
Begriffe, Satzbau, Anrede, Satzfragmente, Leerzeichen, Platzhalter und
Steuerzeichen wurden überprüft. Alle drei Fassungen werden mit den tatsächlichen
Rasterfonts und dem TextBox-Umbruch der Engine geprüft. Radiozeilen müssen auch
nach dem Zusammensetzen in ihre feste 18-Zeichen-Zeile passen. Native Gen2-
Attacken-/Itembeschreibungen und sämtliche 251 Pokédex-Seiten werden auf
Zeilenbreite und Seitenhöhe geprüft.

64 NPC-Tauschdatensätze verwenden die offiziellen Spitznamen; Gen2 zusätzlich
die jeweiligen OT-Namen. Spezielle Geschenke (Pottrott, Post-Habitak und Kristalls
seltsames Ei) bekommen die Namen aus der passenden ROM. Die Namen werden im
Pokémon-Datensatz gespeichert. Ein Sprachwechsel benennt bereits vorhandene
Pokémon oder selbst benannte Boxen nicht um. Pottrott bleibt bei aktivierter Mod
auch nach einem englischen Neustart beim ursprünglichen Besitzer abgebbar;
Spezies-, OT-ID-, KP- und Zufriedenheitsprüfungen bleiben erhalten.

Die gezielten Spieltests benutzen separate neue Testspielstände: echte
Schwester-Joy-Interaktion mit Heilung und Statuskur, einen wilden Kampf mit
Tasteneingaben bis zum Sieg, Speichern/Laden, Namensschutz, Urkunde und Abspann.
Der vollständige Profilvergleich läuft mit der unterstützten 4X-Spielgeschwindigkeit;
ausgewählte Aufbauprüfungen liefen zuvor bei Normalgeschwindigkeit. Fortschritt
wird für diese Tests vorbereitet, kein kompletter Spielverlauf simuliert.
Die lokalen Link-Tests verbinden zwei echte ENet-Endpunkte auf demselben Mac,
prüfen den Handshake, Akzente in Spitznamen/OT und die strikte Rekonstruktion
übertragener Pokémon. Gen2-Tauschgeschenke werden zusätzlich mit der echten
NPC-Tauschfunktion erzeugt; das Post-Habitak läuft durch die Skript-VM und
das lokalisierte seltsame Ei durch den normalen Schlupfcode. Gen1 verwendet
die echte Tausch-Skriptfunktion mit
synchronen Testantworten für die Dialoge und Auswahl.

## GBA-Texte in Preview 4

245 ergänzende UI-Einträge je Sprache decken Deutsch, Spanisch, Französisch und
Italienisch ab: Kampf-/Itemmeldungen, Online-/Link-Menüs, Einstellungen,
Tastenbelegung, Ereignistickets und Wunderkarten. Der Katalog enthält sowohl
geprüfte gemeinsame Menütexte als auch neu verfasste GBA-Texte. Die begrenzte
Quelltextprüfung erfasst alle 180 festen `Strings`-Aufrufe unter
`src/core/game3` und `src/ui/game3`, einschließlich verketteter Literale und
Inline-Aufrufe. Dynamische Einstellungs- und Tastenlabels werden zusätzlich
im laufenden Spiel geprüft. Das ist keine automatische Erkennung jedes
möglichen englischen Textes in sämtlichen Spielpfaden.

Übersetzungen aus der gewählten ROM haben Vorrang vor ergänzenden UI-Texten.
Eine gezielte Ausnahme ist die Menügruppe „SPEED“: Hier geht es um Spieltempo,
nicht um den Pokémon-Statuswert „INIT.“. Dynamische Zoom-/Bildschirmanzeigen
bleiben ebenfalls sprachgerecht. Der Katalog und die Laufzeitkorrekturen sind
Bestandteil des Compiler-Schlüssels; vorhandene Caches werden neu aufgebaut.

Die drei FRLG-Schlüssel `sPluralTxt`, `sText_IES` und `sText_S` stammen aus
Code, der im Original ausschließlich für Englisch kompiliert wird. Die Mod
verwendet jetzt auch in Skripten und im Pokémon-Sprungspiel den regionalen
Itemnamen, ohne englische S-/IES-Endung. Die unbenutzten Hilfseinträge sind leer.
Das gilt bei jeder Menge; Item-IDs, Mengen und Spielregeln bleiben erhalten.

Eigennamen aus US-Abspannregistern werden unverändert erhalten und ausdrücklich
als solche gezählt: zwei Einträge bei Smaragd und 13 bei Rubin/Saphir.
Fehlende Editions-/Funktionsüberschriften in Rubin/Saphir werden ergänzt.
Der tatsächlich angezeigte Abspann verwendet weiterhin sein natives regionales
Datenpaket. Der Prüfbericht unterscheidet ROM-Übersetzungen, verfasste
Überschriften, erhaltene Eigennamen und nicht anwendbare englische Hilfseinträge.
Im geprüften GBA-Textregister bleibt kein ungeklärter Schlüssel übrig.

Alle zwölf unterstützten GBA-Sprachprofile werden jeweils beim Neuaufbau und
beim Neustart mit Cache geprüft. Dazu kommen englische und deaktivierte
Neustarts aller fünf GBA-Editionen. Die Tests prüfen tatsächliche Rasterglyphen,
Formatwerte mit Akzenten, TextBox-Umbruch, feste Wunderkartenfelder, dynamische
Menülabels, native Abspannzeilen gegen ROM-Pointer, regionale Item-Plurale,
unveränderte Pokémon-Kampfwerte, individuelle Spitznamen und Speichern/Laden.
GB/GBC-Ergebnisse aus Preview 3 werden mit Herkunftsvermerk übernommen; deren
Quellen und der gemeinsame Startpfad sind unverändert. Die privaten Logs und
Bilder bleiben außerhalb der ZIP. Eine unabhängige muttersprachliche Abnahme
und komplette manuelle Spieldurchläufe bleiben offen.

## Kurzfristiges Nachlektorat in Preview 5

Alle 5.540 Zellen der ergänzenden Kataloge werden erneut automatisch auf
Format-/Steuerzeichen und mögliche englische Satzreste geprüft: 1.520 GB/GBC-
Schlüssel in drei und 245 GBA-Schlüssel in vier Sprachen. Der gezielte zweite
KI-Lektoratsdurchgang betrachtet dabei Satzfragmente, Meldungen mit mehreren
Platzhaltern, Ereignisbegriffe und mögliche Geschlechtsannahmen.

Fünf Formulierungen sind verbessert: die bisher englische Meldung
„contribution is not a table“ in ES/FR/IT, die französische Startfehlermeldung
und die spanische Meldung für einen beschäftigten Link-Partner. Die letzte
Formulierung passt jetzt auch bei weiblichen oder unbekannten Trainern.
Offizielle ROM-Dialoge, Eigennamen und Spielregeln sind unverändert.

Neun GB/GBC-Katalogtests prüfen die aktualisierten Texte mit den echten
Rasterfonts und dem TextBox-Umbruch. Die 24 GBA-Profilläufe (neu/Cache) und
zehn Englisch-/Deaktivierungsstarts werden ebenfalls mit diesem Stand geprüft.
Breitere Szenen-/Spielprüfungen aus früheren Previews sind im Bericht als
übernommene Ergebnisse gekennzeichnet. Vollständige Spieldurchläufe und eine
unabhängige muttersprachliche Abnahme sind nicht Bestandteil dieser Kurzprüfung.

## Verbleibende Grenzen

- Eine unabhängige Abnahme durch Muttersprachler und komplette manuelle
  Spieldurchläufe bleiben als externe Freigabeschritte offen.
- Windows und Linux wurden nicht praktisch geprüft. Öffentliche Online-Räume,
  vollständige Link-Kämpfe zwischen zwei Geräten und eine erschöpfende Prüfung
  aller Kampf-/Sonderereignispfade stehen ebenfalls noch aus. Hot-Reload zwischen
  Sprachmods ist nicht Teil der Freigabe; für einen Sprachwechsel die Engine neu starten.
- Die PT-BR-Arbeit muss anschließend gezielt mit dieser Branch zusammengeführt
  und gemeinsam geprüft werden. Diese Preview enthält den stabilen Stand plus
  die hier genannten europäischen Profile.

## Welche Sprach-ROMs fehlen noch?

Für die restlichen französischen, italienischen und spanischen Editionen
fehlen 17 Dateien und anschließend deren jeweilige Profile:

| Sprache | Editionen |
|---|---|
| Französisch | Rot, Blau, Gelb, Kristall, Feuerrot, Rubin, Saphir |
| Italienisch | Rot, Blau, Gelb, Silber, Blattgrün, Rubin, Saphir |
| Spanisch | Blau, Rubin, Saphir |

Hinzu kommen elf japanische Editionen, koreanisches Gold/Silber und optional
japanisches Grün mit eigener Editionszuordnung. Japanisch und Koreanisch
benötigen zusätzliche Zeichensatz- und Layout-Arbeit. Chinesische Fanpatches
und Portugiesisch brauchen eigene definierte Quellen; sie sind keine regulären
Handelsfassungen dieser Liste. Die exakten Dateinamen, Revisionen und Prüfsummen
stehen in Weitere-Sprachen.html.
Die GBA-Tests verwenden vorhandene private, anhand der Profil-Prüfsummen
verifizierte Entwicklungsinputs. Die ursprüngliche Bestandsliste fehlender
eigener Feuerrot-/Saphir-Dumps wird dadurch nicht zu einer Beschaffungsliste
oder ROM-Beigabe; zum Spielen brauchst du weiterhin deine passende eigene Datei.

## Lizenz

GPLv3 und die bestehenden Drittanbieterbedingungen bleiben erhalten.
Ein Kopier- oder Forkverbot kann diesem GPL-Paket nicht wirksam hinzugefügt
werden. LICENSE-POLICY.md erklärt die Grenzen und die Projektkennzeichnung.

## Prüfumfang

Der maschinenlesbare Prüfbericht EUROPE-QA.json nennt die bestandenen
Szenen-, Menü-, Katalog-, Spiel-, Link- und Neustartprüfungen sowie die
sechs Unit-/Katalogprüfungen. Der Grafik-Roundtrip umfasst 339 Bilder.
Die privaten Logs und Screenshots verbleiben unter build/.

Der isolierte macOS-Test verwendet ausschließlich private ROM-Imports und
separate QA-Spielstände. Für jedes der 13 neuen Profile werden Aktivierung und
Sprache geprüft. GB/GBC zeigen Titel, Stadt, Pokémon-Center, Markt und einen
wirklichen Kartendialog; Gen2 zusätzlich den metrischen Pokédex. Dabei werden
Pokémon- und Attacken-Kampfwerte mit der US-Basis verglichen. FRLG prüft
Feldansichten, Pokémon-Zusammenfassung, unveränderte Basiswerte und Speichern.
Die Ergebnisliste wird im Entwicklungsverzeichnis unter
build/european-live-results.json abgelegt. Die Preview enthält keine ROMs,
Spielstände oder extrahierten ROM-Grafiken.

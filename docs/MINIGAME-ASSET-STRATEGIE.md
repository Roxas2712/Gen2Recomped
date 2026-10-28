# Strategie für optionale Minispiel-Assets

Stand: 28. Oktober 2026. Konzept von Roxas2712; noch keine rechtliche Freigabe
und keine vollständig implementierte Asset-Umstellung.

## Ziel und rechtliche Grenzen

Die Minispiele benötigen kein Konto. Nach der aktualisierten Produktvorgabe
bleibt der Einstieg jedoch bis zur ausdrücklichen Annahme der Inhaltshinweise
gesperrt, auch im vorgesehenen Standardmodus. Ein zentraler Asset-Vertrag gilt für alle im Spielkatalog
registrierten Minispiele, einschließlich weiterer Spiele wie Schiffe oder
Slide. Die Anzahl der Einträge darf nicht als fest verdrahtete Neun in einer
Zustimmungsabfrage stehen.

Eine Zustimmung erzeugt keine Lizenz für Nintendo-/Pokémon-Inhalte und
überträgt deren Rechte nicht an den Spieler. Kostenlosigkeit, selbst gezeichnete
Darstellungen bekannter Figuren, heruntergeladene Fan-Sprites und ein
Ressourcenlink sind ebenfalls keine pauschale Rechtefreigabe. Auch Code und
lokales Zusammenführen sind nicht automatisch rechtlich unbedenklich.
Eine öffentliche Fassung benötigt eine Prüfung des konkreten Inhalts,
seiner Herkunft, der Nutzungsart und der betroffenen Rechtsordnungen.

Primärquellen:

- [§ 16 UrhG: Vervielfältigung](https://www.gesetze-im-internet.de/urhg/__16.html)
- [§ 23 UrhG: Bearbeitungen](https://www.gesetze-im-internet.de/urhg/__23.html)
- [§ 53 UrhG: Grenzen privater Kopien](https://www.gesetze-im-internet.de/urhg/__53.html)
- [§ 95a UrhG: technische Schutzmaßnahmen](https://www.gesetze-im-internet.de/urhg/__95a.html)
- [EUIPO: Markensymbole sind nicht verpflichtend](https://www.euipo.europa.eu/de/help-centre/tm/faq-basic-questions)
- [§ 23 MarkenG: Bezugnahme unter Voraussetzungen](https://www.gesetze-im-internet.juris.de/markeng/__23.html)
- [Nintendo: Video-/Screenshot-Richtlinie](https://www.nintendo.co.jp/networkservice_guideline/index.html)
  Diese Richtlinie ist keine allgemeine Lizenz für Grafiken und Rufe in
  eigenständigen Minispielen.

## Drei getrennte Inhaltswege

| Weg | Inhalt | Verhalten |
| --- | --- | --- |
| Standard | Eigene, eigenständige Figuren, Formen, Hintergründe, Titel und synthetisierte Klänge; zusätzlich nur nachvollziehbar lizenzierte Inhalte | Nach Annahme der Einstiegshinweise spielbar, keine Anmeldung erforderlich |
| Lokaler Import | Vom Spieler gewählte Dateien bzw. unterstützte lokale Cartridge-Daten; keine pauschale Zusage zulässiger Weiterverwendung | Lokal prüfen und vorbereiten; getrennte Freigabe vor erster Verwendung |
| Geprüftes Downloadpaket | Nur Inhalte, für deren konkreten Einsatz die Rechte dokumentiert sind | Quelle, Rechteinhaber, Lizenz und Credits vor Download anzeigen |

Keine vorinstallierten Original-Sprites, Rufe oder Musik und keine eingebauten
Downloadlinks zu ungeprüften Sprite-/ROM-Sammlungen. Eine Lizenz für den Code
oder für das Zusammenstellen eines Sprite-Sheets genügt nicht automatisch für
die darin abgebildeten Figuren. Eigene Ersatzgrafiken müssen eigenständige
Motive sein; bloßes Nachzeichnen oder Umfärben ersetzt diese Prüfung nicht.

## Erststart und spätere Auswahl

Vor dem ersten Einstieg in die Minispiele erscheint ein verpflichtender,
nicht vorab bestätigter Hinweisdialog. Ohne Annahme wird zur vorherigen Ansicht
zurückgekehrt. Die Nutzungsbestätigung zu selbst bereitgestellten Dateien ist
keine Behauptung, alle Rechte an einem Spiel oder an Pokémon zu besitzen.

Die gesonderte Auswahl optionaler Pakete sieht folgende Wege vor:

1. **Mit Standardgrafiken spielen** — nach Annahme der Einstiegshinweise,
   gleichwertig erreichbar und ohne Netzwerkzugriff.
2. **Eigene Dateien importieren** — Dateiauswahl, unterstützte Formate,
   lokale Verarbeitung und konkrete verwendete Kategorien erläutern.
3. **Lizenzierte Zusatzpakete** — nur tatsächlich geprüfte Angebote; keine
   vorbereiteten Links zu ungeklärten Pokémon-Grafikquellen anzeigen.

Eine nicht vorab angekreuzte Bestätigung kann lauten:

> Ich bestätige, dass ich zur vorgesehenen Nutzung der ausgewählten Dateien
> berechtigt bin. Die lokale Verarbeitung räumt mir keine zusätzlichen Rechte
> an fremden Inhalten ein.

Gesonderter Hinweis: Das Projekt ist unabhängig und nicht von Nintendo oder
The Pokémon Company unterstützt. Dieser Hinweis ist eine Klarstellung,
kein Haftungsausschluss gegenüber Rechteinhabern.

Die Bestätigung gilt **einmal je Gerät, Paketfassung und Nutzungsumfang**.
Kein Dialog vor jedem Spielstart. Ein geänderter Paketinhalt, eine neue
Asset-Kategorie oder ein wesentlich anderer Nutzungszweck erfordert eine neue
Auswahl. Die Ablehnung der verpflichtenden Einstiegshinweise lässt die
Minispiele gesperrt; gespeicherter Fortschritt wird nicht gelöscht. Ein Widerruf
schließt eine offene Minispielansicht ohne neue Rundenauszahlung und erfordert
erneute Annahme vor dem nächsten Einstieg. Das Ablehnen eines einzelnen
optionalen Asset-Pakets kann auf Standardassets zurückschalten, sobald der
eigenständige Standardmodus vollständig umgesetzt und geprüft ist.

Eine Haftungsbegrenzung auf Takedown-Anfragen wird nicht zugesagt. Nach
[§ 97 UrhG](https://www.gesetze-im-internet.de/urhg/__97.html) kommen insbesondere
Unterlassung und bei Verschulden Schadensersatz in Betracht; nach
[§ 97a UrhG](https://www.gesetze-im-internet.de/urhg/__97a.html) können bei einer
berechtigten Abmahnung notwendige Aufwendungen verlangt werden. Ein Dialog
zwischen Projekt und Spielern bindet einen fremden Rechteinhaber nicht.

## Bereits umgesetzter gemeinsamer Einstieg

`src/pokewalker/minigames/Enrollment.lua` sperrt den gemeinsamen Minispiel-Hub
vor dem Initialisieren von Spielkontext, Belohnungsbudget und Spielgrafiken.
Ein nicht vorab angekreuztes Häkchen und anschließendes ausdrückliches
**Annehmen & weiter** sind erforderlich. Ohne Annahme kehrt man zurück; ein
fehlgeschlagener Speichervorgang lässt den Einstieg gesperrt.

Der lokale Datensatz `minigames/enrollment.lua` ist nach Konto/Gastprofil
getrennt. Er enthält Hinweisversion, Katalogkennung, Sprache und Zeitpunkt,
keinen Login-Token. Er wird nicht als Bestandteil des Pokéwalker-Snapshots
hochgeladen. Eine neue Hinweisversion oder ein geänderter registrierter
Spielkatalog erfordern erneute Annahme. Unter **Freunde & Cloud** kann die
Annahme widerrufen werden. Lokales Spielen benötigt weiterhin kein Konto.

Dies implementiert die verpflichtende Einstiegshinweis-Annahme. Die separate
Asset-Inventur, lokale Paket-Erzeugung, tatsächlichen Ersatzgrafiken und
Paket-Berechtigungen sind damit noch nicht umgesetzt oder rechtlich freigegeben.
Insbesondere macht der Dialog bereits vorhandene oder später lokal kombinierte
fremde Inhalte nicht automatisch zulässig.

## Gemeinsamer technischer Vertrag

- Spielregeln und Logik referenzieren neutrale Motiv-IDs. Ein zentraler
  Resolver liefert die ausgewählte lokale Darstellung oder ein vollständiges
  Ersatzmotiv. Kein Spiel umgeht diesen Resolver durch direkte Dateipfade.
- Manifest je Paket: ID, Version, Inhaltsdigest, Quelle/Herkunft, Rechteinhaber,
  Lizenz/Nutzungsumfang, Credits, Kategorien, zugeordnete Motiv-IDs sowie
  erforderliche Import-/Hinweisversion. Unbekannte oder unvollständige
  Rechteangaben führen nicht zur Einstufung als freigegebenes Downloadpaket.
- Lokaler Datensatz: Paketdigest, bestätigte Kategorien, Hinweisversion und
  Zeitpunkt. Er dokumentiert die Auswahl; er ist kein Lizenznachweis und
  rechtfertigt keine Kennzeichnung als „rechtlich geprüft“.
- Import läuft in einen getrennten lokalen Asset-Ordner. Dateitypen,
  Größen, Archiveinträge und Pfade werden geprüft. Abbruch, fehlende Dateien,
  beschädigte Pakete und Widerruf führen zu Ersatzassets, nicht zum Absturz.
- Optionale Grafiken/Rufe werden nicht über Cloud-Fortschritt, ModCompass-
  Katalog, Freundesnachrichten oder Minispielprotokolle verteilt. Bestätigungen
  werden nicht als globale Freigabe auf ein neues Gerät übernommen.
- Online-Spiele synchronisieren Regeln, Züge, Ergebnisse und neutrale IDs.
  Unterschiedliche erlaubte Grafikpakete dürfen die Regeln nicht verändern.
  Vorhandene Videoübertragungen nativer Spiele sind ein gesonderter Umfang;
  dieses Konzept macht keine pauschale Aussage über deren Zulässigkeit.
- Sprache und Barrierefreiheit gelten auch für Auswahl, Kategorien,
  Fehlermeldungen, Credits und Widerruf. Musik und Rufe sind unabhängig von
  Grafikpaketen abschaltbar.

## Umsetzung und Abnahme

Zuerst alle tatsächlich eingebundenen Minispiele samt Bildern, Animationen,
Schriftarten, Sounds, Musik, Logos, Titeln und automatisch erzeugten Downloads
inventarisieren. Der bisher geprüfte gemeinsame Pokéwalker-Grafikpfad liest
importierte lokale Spielassets; dadurch ist eine Nutzung in unabhängigen
Minispielen noch nicht rechtlich freigegeben.

Danach Resolver und Paketverwaltung einführen, pro Spiel vollständige eigene
Ersatzassets ergänzen und die Auswahl einmalig vor optionaler Verwendung
einbauen. Zuletzt Release- und Website-/Vorschaubilder anhand einer
Datei-Allowlist mit Herkunftsnachweisen prüfen. Eine Checkbox allein, versteckte
Dateien im Paket oder ein `.gitignore` ersetzen die Prüfung des tatsächlich
ausgelieferten Builds nicht. Bereits veröffentlichte Dateien und ihre Historie
werden separat erfasst; keine automatische Umschreibung der Git-Historie.

Abnahmetests für jedes registrierte Spiel: frisches Profil ohne Konto und Netz,
Ablehnen, Importabbruch, fehlendes/defektes Paket, erneuter Start ohne erneuten
Dialog, geändertes Paket, Widerruf, Gerätewechsel und unterschiedliche lokale
Darstellungen in derselben Online-Partie. Netzwerk- und Paketprüfungen müssen
belegen, dass vor der Auswahl kein optionaler Asset-Download erfolgt und keine
privaten Asset-Dateien im Cloud- oder Freundesprotokoll landen.

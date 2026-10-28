# Strategie für optionale Minispiel-Assets

Stand: 28. Oktober 2026. Konzept von Roxas2712; noch keine rechtliche Freigabe
und keine vollständig implementierte Asset-Umstellung.

## Ziel und rechtliche Grenzen

Alle Minispiele bleiben ohne Konto und ohne fremde Grafiken oder Sounds
spielbar. Ein zentraler Asset-Vertrag gilt für alle im Spielkatalog
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
| Standard | Eigene, eigenständige Figuren, Formen, Hintergründe, Titel und synthetisierte Klänge; zusätzlich nur nachvollziehbar lizenzierte Inhalte | Sofort spielbar, keine Anmeldung und keine Rechteerklärung nötig |
| Lokaler Import | Vom Spieler gewählte Dateien bzw. unterstützte lokale Cartridge-Daten; keine pauschale Zusage zulässiger Weiterverwendung | Lokal prüfen und vorbereiten; getrennte Freigabe vor erster Verwendung |
| Geprüftes Downloadpaket | Nur Inhalte, für deren konkreten Einsatz die Rechte dokumentiert sind | Quelle, Rechteinhaber, Lizenz und Credits vor Download anzeigen |

Keine vorinstallierten Original-Sprites, Rufe oder Musik und keine eingebauten
Downloadlinks zu ungeprüften Sprite-/ROM-Sammlungen. Eine Lizenz für den Code
oder für das Zusammenstellen eines Sprite-Sheets genügt nicht automatisch für
die darin abgebildeten Figuren. Eigene Ersatzgrafiken müssen eigenständige
Motive sein; bloßes Nachzeichnen oder Umfärben ersetzt diese Prüfung nicht.

## Erststart und spätere Auswahl

Vor der ersten Nutzung eines optionalen Pakets erscheint eine Auswahl:

1. **Mit Standardgrafiken spielen** — immer direkt verfügbar, gleichwertig
   erreichbar und ohne Netzwerkzugriff.
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
Auswahl. Ablehnen oder Widerrufen schaltet auf Standardassets zurück; es
entzieht weder Zugang zu den Minispielen noch Fortschritt oder Online-Rechte.

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

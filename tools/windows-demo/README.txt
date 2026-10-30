RETRORECOMPED – WINDOWS-DEMO 20261030.3 (64 BIT)
Integration: Roxas2712. Bestehende Autorenrechte bleiben erhalten.

START UND BISHERIGE DATEN
1. Bisherige Demo schließen, ZIP vollständig entpacken. Alle DLL-Dateien neben
   RetroRecomped.exe lassen.
2. RetroRecomped.exe per Doppelklick öffnen.
3. Ein vorhandenes Profil wird direkt wiederverwendet. Bei mehreren Profilen
   wählst du deinen bisherigen Ordner. Die Auswahl wird für später gemerkt.

Die Suche umfasst die üblichen Gen2Recomp-, älteren LOVE- und Preview-Profile.
ROM-Importe, Spielstände, installierte Mods und Konto bleiben an ihrem Ort.
Es werden keine alten Profile verschoben, zusammengeführt oder gelöscht.
Profil-Auswahl.cmd zeigt die Auswahl bei Bedarf erneut; dafür muss keine
Spielstand- oder Einstellungsdatei gelöscht werden.
Ist die Profilsuche nicht möglich, wird der Fehler angezeigt. Dann nicht
vorschnell ein neues Spiel beginnen; der bisherige Datenordner bleibt erhalten.

Portable Installation: Programmdateien in deinen bisherigen Programmordner
kopieren. portable.txt, Spielstände, Mods und Datenordner behalten. Dieses ZIP
enthält selbst keinen Portable-Marker und überschreibt keine Benutzerdateien.
Eine Windows-Sicherheitsmeldung kann bei einer unsignierten Test-EXE erscheinen.

EINFACHE CLOUD
Im Launcher bei deinem ModCompass-Konto anmelden. Automatischer normaler
Spielstand-Abgleich ist empfohlen; Anbieterschlüssel und Cloud-Ordner entfallen.
Bereits angemeldet? Einstellungen > Automatische Konto-Cloud einrichten.
Normale Saves werden im Hintergrund übertragen. Offline-Uploads bleiben über
Neustarts erhalten und werden später erneut versucht. Vor Gerätewechsel auf
die Cloud-Bestätigung warten. Konto-Profile bleiben getrennt.

Exakte portable Zwischenstände weiterhin ausdrücklich speichern/hochladen.
ROM-/Import-Uploads sind eine getrennte Einstellung. Kein Spiel wird mitgeliefert.

DIAGNOSE FÜR DEN WINDOWS-TEST
Cloud-Test.cmd startet einen getrennten QA-Test ohne Zugriff auf dein Profil.
Er prüft die mitgelieferte HTTPS-Bibliothek, einen echten öffentlichen HTTPS-
Aufruf sowie Save-/Profil-Regressionsfälle mit künstlichen Daten. Er meldet
damit keinen erfolgreichen Upload deiner echten Spielstände. Die JSON-Ausgabe
und der Logpfad erscheinen danach im Fenster. Für den vollständigen Kontotest
normal starten, anmelden, im Spiel speichern und den Save auf Gerät B prüfen.

UMFANG
Dieses Paket enthält die aktuelle Launcher-/Cloud-Implementierung sowie eine
zur Engine passende, separat qualifizierte Windows-LuaJIT-Laufzeit. Struktur-
und Integritätsprüfungen ersetzen keinen Test der fertigen EXE auf deinem PC.
Optionale native 3DS-/Pinball-Zusatzlaufzeiten aus dem Mac-Paket werden nicht
als Windows-DLL ausgegeben; dafür sind passende Windows-Komponenten nötig.
Bestehende private Imports werden deshalb weder entfernt noch neu erzeugt.

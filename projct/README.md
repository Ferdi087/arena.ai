# Möbel-Rambo – Umzugssimulator (Godot 4.x)

Physischer Umzugs-/Detektiv-Simulator: **Open-City-HQ-Slice** mit echten
physikalischen Möbeln (kein Inventar!), LKW-Ladungsphysik, wackeligen
Ragdoll-Charakteren, Runtime-Sprühsystem, Daten-getriebenen Missionen
(inkl. Spezial-Jobs), lokalem Co-op (Split-Screen) ab Tag eins, Savegames und
AAA-Grafikoptionen, die alle **real** wirken.

Projekt-Root ist `projct/` (Godot-Projektordner). Engine: Godot **4.7**, Physik
**Jolt**. Alle Skripte sind typisiertes GDScript 2.0, jede Klasse eine Datei,
Komponenten vor Vererbung.

## Starten

1. Godot 4.7 (mit Jolt-Support, z. B. offizielles Build ab 4.4) installieren.
2. Diesen Ordner in Godot als Projekt öffnen (`projct/project.godot`).
3. **F5** – das Hauptmenü startet (`scenes/menus/main_menu.tscn`).
   Neues Unternehmen gründen → Charakter erstellen → HQ erscheint.

Beim ersten Start legt Godot die `.import`-Dateien für die generierten Sounds
an. Falls Sounddateien fehlen: `python3 tools/generate_sfx.py` (pure Stdlib,
erzeugt 37 Wav-Banken in `audio/sfx/`), sonst bleibt es stumm, crasht aber
nicht (audio_manager degradiert).

## Steuerung (Tastatur/Maus + Controller gemischt)

| Aktion | Taste(n) |
|---|---|
| Bewegen / Sprint / Sprung | W A S D · Shift · Space |
| Greifen / Halten | RMB gedrückt |
| Werfen | RMB los (mit Schwung) |
| Drehen am Objekt | Q / E |
| Interagieren / Einsteigen | E · F aussteigen |
| Werkzeugleiste | 1–5, Blättern mit `[` `]` |
| Sprühen/Hämmern (aktives Werkzeug) | LMB (`tool_use`) |
| Baumodus (HQ) | B, Platzieren RMB, Rotieren R, Entfernen Mitteltaste, Etage C/V |
| Karte / Menü | M · Esc |
| Hupe | H |
| Spieler 2 (lokal) | zweiter Controller (Linker Stick/A/X; Grab = Y) |

Handbremse ist `crouch` (Standard: Strg bzw. Bumper) – bewusst belegt statt
Extra-Key.

## Architektur-Kurzfassung (Details: `docs/ARCHITECTURE.md`)

* **Autoloads** = Services, keine Spielsysteme: `Content` (Katalog), `Company`,
  `Missions`, `Style`, `Sfx`, `Settings`, `Saves`, `Game`, `Scenes`, `Net`,
  `UI`, `GameInput`, `EventBus`, `Characters`, `Dev`.
* **EventBus** entkoppelt: Gameplay schreibt nie direkt ins UI.
* **GrabHold** löst Griffe als PD-Geschwindigkeits-Ziel an einem
  Generic6DOFJoint3D-Socket – kein Teleportieren, Mehrfachgriffe (mehrere
  Spieler an einem Sofa) mitteln das Ziel.
* **Cargo**: echte RigidBodies bleiben echt, werden beim Verladen an den LKW
  gehängt und per `freeze` fixiert; Gurte (Straps 0–2) verhindern Rausfallen
  bei Querbeschleunigung.
* **Missionen** sind Daten + ein gemeinsamer `MissionRuntime`-Taktgeber –
  keine Mega-Manager pro Sonderszene; Spezialeffekte (Spukhaus, Wolkenkratzer)
  sind `special_rules`-Parameter auf denselben Systemen.
* **Stadt**: analytisches Raster (`CityLayout`) für Visuals, Navi, Minimap und
  Traffic – deterministisch, speicherbar, streamingfähig (`ChunkManager` mit
  Distanz-Tiers: full/sim/freeze).
* **Savegames**: Contributor-Interface (`save_key` + `save_to_dict/apply_save_data`);
  atomare Slots mit Backup + Migration.

## Inhalt erweitern ohne Code

Neue `.tres`-Dateien in `data/definitions/<kategorie>/` werden automatisch
eingelesen und überschreiben/ergänzen per `id`
(FurnitureData, VehicleData, MissionData, BuildPieceData, CosmeticData,
UpgradeData). Beispiele in `docs/CONTENT.md`.

## Testen

```
godot --headless --path projct res://tests/core_tests.tscn
```

Exit-Code 0 = grün. Deckt ab: Katalog-Integrität, Stadt-Routing,
Payout-Modell (Perfekt/Poor/Floor), prozedurale Missions-Invarianten,
Save-Roundtrip. Die Engine selbst kann in dieser Sandbox nicht laufen
(Autoroute blockiert Downloads) – alle 90 Skripte sind mit `gdtoolkit`
(gdparse) validiert.

## Bekannte Grenzen des Slices

* Online-Matchmaking ist simuliert (lokal hosten/beitreten funktioniert über
  `MultiplayerAPI`; Steam/etc. ist als Interface vorbereitet, nicht verschaltet).
* HQ-Welt nutzt das freie Feld; die volle Stadt mit Häusern läuft in
  `scenes/world/city_test.tscn` (Dev-Menü: `+`).
* Musik: nur UI-Blips + prozedurale Bank; Score folgt als Playlist-Slot.

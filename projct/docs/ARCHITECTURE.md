# Architektur – Möbel-Rambo

## Schichten (Import-Richtung ist IMMER nach unten)

```
scenes/*.tscn ─┐ (dünn; fast alles wird im Code aufgebaut → merge-freundlich)
ui/            │ HUD, Screens, UI-Service        → liest Services/EventBus
gameplay/      │ Player, Grab, Furniture, Vehicles│→ nutzt Components, EventBus
  ├─ mission/  │ MissionService + MissionRuntime  │→ liest Content, schreibt Company
  ├─ economy/  │ CompanyService (Geld, Ruf, XP)   │→ emittert EventBus
  ├─ building/ │ BuildMode (HQ-Gitter, Qualität)  │→ Save-Contributor
components/    │ DamageComponent, GrabHold, Cargo… │→ rein physisch, kein UI
core/ services/│ EventBus, Saves, Settings, Net…  │→ keine Spielregeln
data/          │ Content DB + Resource-Klassen    │→ Blätterkatalog, keine Logik
```

## Multiplayer-Grundriss (von Anfang an, #61–#66)

* High-Level-Multiplayer: `MultiplayerSpawner` für Players + Furniture auf dem
  `WorldRoot`; jeder `Player` meldet sich via RPC `announce_self`, der Host
  spawnt und broadcastet `broadcast_remote_player`.
* Authority-Regeln: physische Objekte simulieren alle; **der Halter** (peer mit
  `hold_owner`) kommandiert den GrabHold, andere sehen nur Replikation.
  Zerstörung/Verladung/Bezahlung führt ausschließlich der Host aus
  (`is_authority()`-Check in jedem RPC-Pfad).
* Möbel-Sync: GrabHold schreibt `sync_grab`-RPCs (10 Hz), Cargo-Status
  (`try_load/strap`) ist Host-RPC; disconnect → `release_all_holds_for`.
* Lokal-Co-op: `SplitScreen.attach(player, idx)` spiegelt die Main-Cam per
  `RemoteTransform3D` in ein `SubViewport` (geteilte `world_3d`) – **keine**
  zweite Simulation.
* Online kann über den Editor mit zwei Instanzen (127.0.0.1) getestet werden;
  `Net.host_game()/join_game(ip)` nutzen ENet, UPnP versucht, aber optional.

## Physik-Budget (#70–#76)

* RigidBodies schlafen, bis sie (<45 m) in der Nähe eines Aktivators sind.
* `ChunkManager` (nur in der Stadt-Welt): Distanz-Tiers über Gruppen
  `furniture`/`npcs` – Voll-Sim / nur Kollision / eingefroren+unsichtbar.
* Kollision: pro Möbel genau eine Box-Form (half_extents aus FurnitureData),
  Complex-Shape-Slots sind für spätere Meshes vorbereitet.
* Stadt-Traffic: kinematische Autos (keine RigidBodies!) auf
  CityLayout-Pfadknoten, Fußgänger sind `NPCCarrier` (kinematische
  Box-Figuren) auf Layer Decor → nie Physik-Tuning-Opfer.

## Damage & Payout

`DamageComponent` sammelt Impulse (Referenz-Impuls-Geschwindigkeit aus
`Content.damage_settings`), clamped pro Treffer (Anti-Spike), graduiert
Scratch→Visible→Heavy→Critical→Destroyed. Frakturen (Split-Shapes) für
Glas/Keramik. Der **einzige** Ort der Geldrechnung: `PayoutCalculator.calculate`
(statisch, deterministisch, durch `tests/core_tests.gd` verifiziert).

## Paint / Sprühen

`PaintSurface` (Component) hält ein Image pro Objekt (Base + Paint-Layer),
`tool_controller` streamt Striche (RPC an Halter), `paint_overlay.gdshader`
composited es in Objekt-UV. Pinselparameter aus `ToolController`
(Farbe/Muster/Größe – Palette schreibt dort hinein). Striche werden fürs
Savegame pro `paint_stroke_finished` kompakt gespeichert (PNG base64 im Slot).

## Savegame-Flow

`Saves` sammelt pro Slot ein JSON: Sektionen von Beiträgern über `save_key`.
`build_save_dict` bei Speichern; beim Laden in Menüs (Beitragende noch nicht
in Baum) parkt `pending_sections` die Sektion, bis sich der Contributor
registriert. Version + Migration (`migrate()`). Atomar: tmp → backup → replace.

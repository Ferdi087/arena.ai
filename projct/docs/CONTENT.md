# Content-Pipeline – Daten statt Code (#37, #123)

Derkomplette Katalog lebt in `Content` (Autoload). Zwei Wege, Inhalte zu ergänzen:

## 1. `.tres`-Overlay (empfohlen, kein Code-Wechsel)

Lege eine Resource-Datei unter `res://data/definitions/<typ>/name.tres`:

```
furniture/   → FurnitureData    (Fahrbares Traggut)
vehicles/    → VehicleData      (LKW & Co.)
missions/    → MissionData      (Aufträge inkl. Boss-Struktur)
build/       → BuildPieceData   (HQ-Bauteile)
cosmetics/   → CosmeticData     (Klamotten/Hüte)
upgrades/    → UpgradeData      (Werkstatt)
```

`Content._overlay_from_definitions()` liest alle Dateien ein; gleiche `id`
überschreibt den Katalog-Eintrag (Patches!), neue `id` ergänzt ihn.

### Beispiel-Mission (Textform der .tres)

```
[gd_resource type="Resource" script_class="MissionData"
 load_steps=2 format=3]

[ext_resource type="Script" path="res://data/resources/mission_data.gd" id="1"]

[resource]
script = ExtResource("1")
mission_id = &"job_nachtfalter"
display_name = "Nachtfalter-Umzug"
client_name = "Familie Nachtfalter"
client_type = &"eccentric"
description = "Nur bei Nacht fahren – der Falter mag keine Sonne."
source_district = &"villa"
destination_district = &"oldtown"
furniture_manifest = [Resource("res://data/definitions/furniture/wardrobe_drehtuer.tres"),
	Resource("res://data/definitions/furniture/aquarium_cylinder.tres")]
special_rules = PackedStringArray("night_only", "aquarium_no_tilt")
difficulty = 2
base_payment = 3400.0
time_limit_seconds = 900.0
weather_override = 0
force_night = true
```

Regel: **Alle Manifest-Ids müssen im Katalog existieren** – die
Core-Tests (`tests/core_tests.tscn`) brechen sonst mit klarer Meldung.

## 2. Prozedurale Missions-Invarianten

`Missions._generate_mission()` mischt Level/Ruf-Pool (`Content.mission_pool`)
mit prozeduralen Aufträgen (Gewicht = Marketing!). Prozedurale Jobs erben
Immobilien-Topologie aus `CityLayout` (Quelle & Ziel sind echte
Rasterknoten → Route, Minimap und ETA stimmen automatisch).

`special_rules` ist die einzige Boss-Mechanik-Erweiterung: Die Shared-Systeme
fragen pro Rule ab (`haunted` → `flicker_lights`+`ghost_whoosh`, `aquarium_no_tilt`
→ Zusatz-Damagetab, `messy_hoard` → Trümmerhaufen via `spawn_debris_pile`,
`crane`/`high_wind` → Wind-Modifikator). **Kein neuer Mega-Manager pro Mission.**

## Balancing

Ein Regler-Fenster für alles Physicalische: `Content.damage_settings`
(DamageSettings.tres), Wirtschaft: `Content.economy_settings`
(Marketing-Kosten, Loohn, Kaufkraft). Werte dort ändern wirkt sofort, in allen
Systemen – UI-Texte bleiben korrekt, weil sie die Settings abfragen.

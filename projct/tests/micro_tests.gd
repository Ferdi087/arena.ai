extends Node
## Kleines Zusatz-Set für schnelle manuelle Checks im Editor:
## diese Szene direkt F6 spielen – nutzt CoreTests-Instanz und loggt Details.
## (Vollständigkeit/Exit-Code-Check läuft über core_tests.tscn im Headless.)

func _ready() -> void:
	var t := CoreTests.new()
	add_child(t)

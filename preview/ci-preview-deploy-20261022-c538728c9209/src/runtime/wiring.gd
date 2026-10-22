class_name Wiring
extends RefCounted

## Derives the pin -> part mapping purely from the graph's ELEC links (ADR 0002).

const PIN_PREFIX := "pin_"


## Returns { pin_number: int -> { "part": int, "port": StringName } } for every wired pin.
static func pin_map(graph: ConnectionGraph) -> Dictionary:
	var result := {}
	var ambiguous: Array[int] = []
	for link: Dictionary in graph.links:
		var a_def: PartDef = graph.parts[link.a_part].part_def
		var b_def: PartDef = graph.parts[link.b_part].part_def
		var a_port := _find_port(a_def, link.a_port)
		var b_port := _find_port(b_def, link.b_port)
		if a_port == null or b_port == null or a_port.kind != Port.Kind.ELEC:
			continue
		var pin_a := pin_number(a_port)
		var pin_b := pin_number(b_port)
		var pin: int = pin_a if pin_a >= 0 else pin_b
		if pin < 0:
			continue
		if result.has(pin) or pin in ambiguous:
			result.erase(pin)
			if pin not in ambiguous:
				ambiguous.append(pin)
			continue
		result[pin] = {"part": link.b_part, "port": link.b_port} if pin_a >= 0 else {"part": link.a_part, "port": link.a_port}
	return result


static func pin_number(port: Port) -> int:
	var id := String(port.id)
	if not id.begins_with(PIN_PREFIX):
		return -1
	var digits := id.substr(PIN_PREFIX.length())
	return int(digits) if digits.is_valid_int() else -1


static func _find_port(def: PartDef, port_id: StringName) -> Port:
	for port in def.ports:
		if port.id == port_id:
			return port
	return null

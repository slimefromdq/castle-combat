class_name RelayView
extends Node3D
## Draws the Relay from RelayController state: the gold gem, its pickup ring and
## progress, the drop beacon, the warning telegraph and the delivery pocket outline.
## Read-only, like the rest of the view.

var view: MatchView
var _gem: MeshInstance3D
var _ring: MeshInstance3D
var _fill: MeshInstance3D
var _beam: MeshInstance3D
var _deliver_outline: Node3D
var _deliver_fill: MeshInstance3D
var _pickup_outline: Node3D
var _outlines_for := -1


func _ready() -> void:
	var gem := SphereMesh.new()
	gem.radius = 0.42
	gem.height = 1.1
	gem.radial_segments = 4
	gem.rings = 2
	_gem = UnitFactory.part(self, gem, Palette.RELAY)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Palette.RELAY
	glow.emission_enabled = true
	glow.emission = Palette.RELAY
	glow.emission_energy_multiplier = 0.6
	_gem.material_override = glow
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	ring.rings = 48
	ring.ring_segments = 4
	_ring = UnitFactory.part(self, ring, Color(Palette.RELAY, 0.85), Vector3.ZERO, Vector3.ZERO, true)
	_fill = UnitFactory.part(self, UnitFactory.cylinder(1.0, 1.0, 0.02, 32), Color(Palette.RELAY, 0.45), Vector3.ZERO, Vector3.ZERO, true)
	_beam = UnitFactory.part(self, UnitFactory.cylinder(0.12, 0.25, 7.0, 12), Color(Palette.RELAY, 0.35), Vector3.ZERO, Vector3.ZERO, true)
	_deliver_fill = UnitFactory.part(self, UnitFactory.box(Vector3.ONE), Color(Palette.RELAY, 0.3), Vector3.ZERO, Vector3.ZERO, true)


func render(alpha: float) -> void:
	var sim := view.sim
	var relay := sim.relay
	var t := Time.get_ticks_msec() / 1000.0
	var cfg := sim.config
	var active := relay.state != RelayController.State.DORMANT
	if _outlines_for != relay.activations:
		_rebuild_outlines(sim)
	_pickup_outline.visible = relay.state == RelayController.State.SPAWNED or (relay.state == RelayController.State.DORMANT and relay.warned)
	_deliver_outline.visible = active
	var p := relay.prev_pos.lerp(relay.pos, alpha)
	match relay.state:
		RelayController.State.DORMANT:
			_gem.visible = false
			_beam.visible = false
			_fill.visible = false
			# Warning telegraph: a pulsing ring where the next Relay will appear.
			_ring.visible = relay.warned
			if relay.warned:
				var pulse := 0.6 + 0.4 * sin(t * 6.0)
				_place_ring(relay.origin, cfg.relay_pickup_radius * (0.8 + 0.2 * pulse), Color(Palette.RELAY, 0.35 + 0.4 * pulse))
		RelayController.State.SPAWNED, RelayController.State.DROPPED:
			var dropped := relay.state == RelayController.State.DROPPED
			var locked := dropped and sim.time < relay.lock_until
			_gem.visible = true
			_gem.position = MatchView.to_world(p, 1.1 + 0.15 * sin(t * 3.0))
			_gem.rotation.y = t * 1.6
			_place_ring(p, cfg.relay_pickup_radius, Color(0.8, 0.8, 0.8, 0.6) if locked else Color(Palette.RELAY, 0.85))
			var progress := maxf(relay.pickup_progress[0], relay.pickup_progress[1]) / cfg.relay_pickup_time
			_fill.visible = progress > 0.0
			var r := cfg.relay_pickup_radius * clampf(progress, 0.0, 1.0)
			_fill.position = MatchView.to_world(p, 0.05)
			_fill.scale = Vector3(r, 1, r)
			# Dropped: a tall beacon so everyone sees where it fell.
			_beam.visible = dropped
			_beam.position = MatchView.to_world(p, 3.5)
			(_beam.material_override as StandardMaterial3D).albedo_color.a = 0.25 + 0.2 * sin(t * 8.0)
		RelayController.State.CARRIED:
			_ring.visible = false
			_fill.visible = false
			_beam.visible = false
			_gem.visible = true
			var carrier := relay.carrier(sim)
			var at := view.unit_position(carrier.id) if carrier != null else MatchView.to_world(p)
			_gem.position = at + Vector3(0, 2.7 + 0.1 * sin(t * 4.0), 0)
			_gem.rotation.y = t * 3.0
	# Delivery progress fills the delivery pocket from its floor.
	var k := relay.deliver_progress / cfg.relay_deliver_time if relay.state == RelayController.State.CARRIED else 0.0
	_deliver_fill.visible = k > 0.0
	if _deliver_fill.visible:
		var rect := relay.delivery_rect(sim)
		_deliver_fill.position = MatchView.to_world(rect.get_center(), 0.04)
		_deliver_fill.scale = Vector3(rect.size.x * k, 0.03, rect.size.y * k)


func _place_ring(p: Vector2, radius: float, color: Color) -> void:
	_ring.visible = true
	_ring.position = MatchView.to_world(p, 0.06)
	_ring.scale = Vector3(radius, 0.03, radius)
	(_ring.material_override as StandardMaterial3D).albedo_color = color


## Gold outline on the delivery pocket, a fainter one on the pickup pocket.
func _rebuild_outlines(sim: MatchSim) -> void:
	_outlines_for = sim.relay.activations
	if _deliver_outline != null:
		_deliver_outline.queue_free()
		_pickup_outline.queue_free()
	_deliver_outline = _outline(sim.relay.delivery_rect(sim), Color(Palette.RELAY, 0.95), 0.22)
	_pickup_outline = _outline(sim.relay.pickup_rect(sim), Color(Palette.RELAY, 0.45), 0.12)


func _outline(rect: Rect2, color: Color, w: float) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var r := rect.grow(-0.15)
	var c := MatchView.to_world(r.get_center(), 0.05)
	UnitFactory.part(root, UnitFactory.box(Vector3(r.size.x, 0.03, w)), color, c + Vector3(0, 0, r.size.y / 2.0), Vector3.ZERO, true)
	UnitFactory.part(root, UnitFactory.box(Vector3(r.size.x, 0.03, w)), color, c - Vector3(0, 0, r.size.y / 2.0), Vector3.ZERO, true)
	UnitFactory.part(root, UnitFactory.box(Vector3(w, 0.03, r.size.y)), color, c + Vector3(r.size.x / 2.0, 0, 0), Vector3.ZERO, true)
	UnitFactory.part(root, UnitFactory.box(Vector3(w, 0.03, r.size.y)), color, c - Vector3(r.size.x / 2.0, 0, 0), Vector3.ZERO, true)
	return root

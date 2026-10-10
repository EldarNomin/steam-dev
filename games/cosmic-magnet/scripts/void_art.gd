class_name VoidArt
extends RefCounted
## Small source sheets are kept byte-for-byte. No gameplay state or wall-clock timer.
const SKIFF := preload("res://assets/void/skiff.png")
const ENGINE := preload("res://assets/void/engine.png")
const POWER := preload("res://assets/void/engine-power.png")
const DERELICT := preload("res://assets/void/derelict.png")
const BATTERY := preload("res://assets/void/battery.png")
const MODULE := preload("res://assets/void/module.png")
const RELAY := preload("res://assets/void/relay.png")
const BACKGROUND := preload("res://assets/void/background.png")
const STARS := preload("res://assets/void/stars.png")
const PLANET := preload("res://assets/void/planet.png")

static func frame(texture: Texture2D, time: float, cell: Vector2, fps := 10.0) -> Rect2:
	var count := maxi(1, int(texture.get_width() / cell.x))
	return Rect2(Vector2((int(time * fps) % count) * cell.x, 0), cell)

static func draw_sheet(node: CanvasItem, texture: Texture2D, rect: Rect2, time: float, cell: Vector2, tint := Color.WHITE, fps := 10.0) -> void:
	node.draw_texture_rect_region(texture, rect, frame(texture,time,cell,fps),tint)

static func icon(texture: Texture2D, cell := Vector2(32,32)) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2.ZERO, cell)
	return atlas

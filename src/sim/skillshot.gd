class_name Skillshot
extends RefCounted
## A projectile that flies in a straight line and hits what it touches (Avery's Judgment
## Blade, Jose's Sweet Talk, Jack's cloak). Unlike basic attacks, these can miss: they
## are aimed at where the target was, and walls stop them.

var id := 0
var owner: HeroState
var ability: AbilityData
var pos := Vector2.ZERO
var dir := Vector2.ZERO
var speed := 10.0
var width := 0.5
## Metres left before it lands.
var left := 0.0
var damage := 0.0
var minion_damage := 0.0
## Passes through what it hits (the cloak), or stops at the first hit.
var pierce := false
## Stops at the first enemy hero but passes through troopers (Judgment Blade).
var stop_at_hero := false
## Charge fraction 0..1 (Sweet Talk), for visuals.
var charge := 0.0
var key := 0
var done := false
## Entity ids already hit.
var hits := {}

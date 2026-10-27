class_name PlayerCommand
extends RefCounted
## Everything a player (human, bot or later the network) can ask for on one tick.
## The sim decides what actually happens.

## Desired movement in sim space, length 0..1.
var move := Vector2.ZERO
## Tap-to-target override: entity id to focus, -1 to clear it, 0 for no change.
var target_id := 0
## Ability to cast this tick: 0, 1 or 2 (the ultimate), or -1.
var cast_slot := -1
## Where a person is aiming (sim space, unit length), or zero to let aimed abilities pick
## a target themselves (bots). Skillshots and dashes fly this way when it is set.
var aim := Vector2.ZERO
var drop_relay := false
## Perk choice (0 or 1) for the earliest level-up perk not yet picked, or -1.
var perk_pick := -1
## Deck card slot to buy, or -1.
var buy_slot := -1
## Deck card slot whose owned item to sell back, or -1.
var sell_slot := -1
## Buy a siege scroll (level 7+, at the shop).
var buy_scroll := false
## Deck card slot whose owned item to make a Masterwork (level 8+), or -1.
var masterwork_slot := -1
## Use the hero's Trick (Blink, Cleanse, Barrier or Brand) this tick. Blink goes the way
## of `aim`, else `move`.
var use_trick := false

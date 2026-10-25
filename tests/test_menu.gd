extends TestCase
## Main menu: hero pick, item deck building and the Play gate.


func _menu() -> MainMenu:
	var menu := MainMenu.new()
	menu._ready()  # Not in a tree: build it by hand.
	return menu


func test_menu_starts_on_battle_with_default_deck() -> void:
	var menu := _menu()
	check(menu.current_tab == MainMenu.Tab.BATTLE, "opens on the Battle tab")
	check(menu.deck == Array(MatchController.DEFAULT_DECK, TYPE_INT, "", null), "default deck pre-picked")
	check(menu.deck_full(), "default deck is full")
	check(menu._hero_name.text == MatchController.HEROES[0].display_name.to_upper(), "showcase names the hero")
	menu.free()


func test_pick_hero_updates_showcase() -> void:
	var menu := _menu()
	menu.pick_hero(2)
	check(menu.hero_index == 2, "hero index stored")
	check(menu._hero_name.text == MatchController.HEROES[2].display_name.to_upper(), "name plate follows the pick")
	check(menu._kit_label.text.contains(MatchController.HEROES[2].abilities[0].display_name), "kit lists the hero's abilities")
	menu.free()


func test_deck_toggle_and_play_gate() -> void:
	var menu := _menu()
	var played := [0]
	menu.play_requested.connect(func() -> void: played[0] += 1)
	var first: int = menu.deck[0]
	menu._toggle_item(first)
	check(not menu.deck.has(first), "tapping a deck card takes it out")
	check(not menu.deck_full(), "deck now short")
	menu._on_play()
	check(played[0] == 0, "Play does nothing with a short deck")
	check(menu.current_tab == MainMenu.Tab.HEROES, "Play sends you to Heroes & Items instead")
	var spare := -1
	for i in MatchController.ITEMS.size():
		if not menu.deck.has(i) and i != first:
			spare = i
			break
	menu._toggle_item(spare)
	check(menu.deck_full() and menu.deck.has(spare), "adding a card fills the deck")
	var before := menu.deck.duplicate()
	menu._toggle_item(first)
	check(menu.deck == before, "a full deck refuses a ninth card")
	menu._on_play()
	check(played[0] == 1, "Play starts a match with a full deck")
	menu.free()

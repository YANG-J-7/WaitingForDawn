extends Node
## 参考图HUD布局；保留主场景原有控件、信号和真实数据。
const Icon = preload("res://src/gameplay/art/hud_icon.gd")
const Face = preload("res://src/gameplay/art/hud_card_face.gd")
const Clock = preload("res://src/gameplay/art/day_night_clock.gd")
const StatusSymbol = preload("res://src/gameplay/art/hud_status_symbol.gd")
var main: Node
var shop_heading: HBoxContainer
var shop_subtitle: Label
var settings_panel: PopupPanel
var day_night_clock: Control
var right_status: HBoxContainer
var pause_symbol: Control
var settings_button: Button

func install(owner_main: Node) -> void:
	main = owner_main
	main.top_bar.get_node("Margin").hide()
	main.get_node("HUD/ResourcesBar").hide()
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color("0b1724",0.98)
	top_style.border_color = Color("2b4052")
	top_style.border_width_bottom = 1
	top_style.content_margin_left = 5
	top_style.content_margin_right = 5
	top_style.content_margin_top = 0
	top_style.content_margin_bottom = 0
	main.top_bar.add_theme_stylebox_override("panel",top_style)
	main.top_bar.custom_minimum_size.y = 32
	main.top_bar.offset_bottom = 32
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",7)
	main.top_bar.add_child(row)
	var values: Array = [main.wood_value,main.food_value,main.stone_value,main.iron_value,main.gold_value,main.population_value]
	var keys := ["wood","food","stone","iron","gold","population"]
	for i in range(values.size()):
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation",3)
		row.add_child(group)
		group.add_child(icon(keys[i],19))
		values[i].reparent(group)
		values[i].add_theme_font_size_override("font_size",12)
	main.train_farmer_button.reparent(row)
	main.train_farmer_button.custom_minimum_size = Vector2(36,32)
	main.train_farmer_button.add_theme_font_size_override("font_size",12)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := main.train_farmer_button.get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		main.train_farmer_button.add_theme_stylebox_override(state,style)
	spacer(row)
	day_night_clock = Clock.new()
	row.add_child(day_night_clock)
	day_night_clock.configure(main.campaign_time_value)
	spacer(row)
	right_status = HBoxContainer.new()
	right_status.name = "RightStatus"
	right_status.add_theme_constant_override("separation",0)
	row.add_child(right_status)
	var threat_margin := status_margin(10)
	threat_margin.name = "ThreatSection"
	threat_margin.custom_minimum_size.x = 94
	right_status.add_child(threat_margin)
	var threat := HBoxContainer.new()
	threat.add_theme_constant_override("separation",6)
	threat_margin.add_child(threat)
	threat.add_child(status_symbol("threat",22))
	threat.add_child(label("威胁",12))
	main.wave_value.reparent(threat)
	main.wave_value.add_theme_font_size_override("font_size",15)
	main.wave_value.add_theme_color_override("font_color",Color("e53b47"))
	status_separator(right_status)
	var city_margin := status_margin(8)
	city_margin.name = "CitySection"
	right_status.add_child(city_margin)
	var city_group := HBoxContainer.new()
	city_group.add_theme_constant_override("separation",7)
	city_margin.add_child(city_group)
	city_group.add_child(status_symbol("city",22))
	var city := VBoxContainer.new()
	city.add_theme_constant_override("separation",2)
	city.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	city_group.add_child(city)
	var city_row := HBoxContainer.new()
	city_row.add_theme_constant_override("separation",4)
	city.add_child(city_row)
	city_row.add_child(label("主城",12))
	main.city_value.reparent(city_row)
	main.city_value.add_theme_font_size_override("font_size",12)
	main.city_value.add_theme_color_override("font_color",Color("f3efdf"))
	main.city_health_bar.reparent(city)
	main.city_health_bar.custom_minimum_size = Vector2(110,5)
	main.city_health_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	main.city_health_bar.add_theme_stylebox_override("background",Icon.box(Color("1d2c3b"),Color("354858"),2))
	var health_fill := Icon.box(Color("47c688"),Color("6cdda0"),1)
	health_fill.set_border_width_all(0)
	health_fill.border_width_top = 1
	main.city_health_bar.add_theme_stylebox_override("fill",health_fill)
	status_separator(right_status)
	main.campaign_pause_button.reparent(right_status)
	pause_symbol = style_status_button(main.campaign_pause_button,"pause")
	status_separator(right_status)
	settings_button = Button.new()
	settings_button.name = "SettingsButton"
	settings_button.text = "设置"
	settings_button.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_button.tooltip_text = "显示设置"
	right_status.add_child(settings_button)
	style_status_button(settings_button,"settings")
	settings_button.pressed.connect(show_settings)
	for button in [main.hand_prev_button,main.hand_next_button,main.shop_close_button,main.refresh_button]:
		button.add_theme_stylebox_override("normal",Icon.box(Color("101c28"),Color("92764b")))
		button.add_theme_stylebox_override("hover",Icon.box(Color("24364a"),Color("efc675")))
		button.add_theme_color_override("font_color",Color("f4e8cd"))
	main.hand_bar.add_theme_stylebox_override("panel",panel_style())
	main.day_setup_panel.add_theme_stylebox_override("panel",panel_style())
	main.hand_bar.offset_top = -112
	main.hand_label.custom_minimum_size = Vector2(60,90)
	main.hand_label.add_theme_font_size_override("font_size",15)
	main.hand_label.add_theme_stylebox_override("normal",Icon.box(Color("101c28"),Color("374652")))
	main.hand_prev_button.custom_minimum_size = Vector2(32,44)
	main.hand_next_button.custom_minimum_size = Vector2(32,44)
	main.hand_prev_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main.hand_next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main.hand_scroll.custom_minimum_size.y = 94
	main.hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	main.hand_slots.add_theme_constant_override("separation",10)
	main.get_node("HUD/HandBar/Margin").add_theme_constant_override("margin_top",7)
	main.get_node("HUD/HandBar/Margin").add_theme_constant_override("margin_bottom",7)
	shop_heading = main.day_title.get_parent()
	shop_heading.add_theme_constant_override("separation",8)
	var shop_symbol := icon("coins",27)
	shop_symbol.name = "ShopSymbol"
	shop_heading.add_child(shop_symbol)
	shop_heading.move_child(shop_symbol,0)
	var gold_symbol := icon("gold",22)
	gold_symbol.name = "GoldSymbol"
	shop_heading.add_child(gold_symbol)
	shop_heading.move_child(gold_symbol,shop_heading.get_children().find(main.selection_label))
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.add_theme_constant_override("separation",0)
	shop_heading.add_child(title_column)
	shop_heading.move_child(title_column,1)
	main.day_title.reparent(title_column)
	shop_subtitle = label("战斗继续进行",11)
	title_column.add_child(shop_subtitle)
	main.day_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.selection_label.add_theme_color_override("font_color",Color("f6c568"))
	main.day_setup_panel.get_node("Margin").add_theme_constant_override("margin_left",10)
	main.day_setup_panel.get_node("Margin").add_theme_constant_override("margin_right",10)
	main.day_setup_panel.get_node("Margin").add_theme_constant_override("margin_top",6)
	main.day_setup_panel.get_node("Margin").add_theme_constant_override("margin_bottom",6)
	main.card_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.card_grid.add_theme_constant_override("v_separation",8)
	main.card_grid.add_theme_constant_override("h_separation",10)
	for button in main.card_buttons:
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var face := Face.new()
		face.name = "ReferenceFace"
		face.shop = true
		face.hide()
		button.add_child(face)
	main.refresh_button.add_theme_font_size_override("font_size",14)
	main.refresh_button.icon = Icon.icon_texture("refresh")
	main.refresh_button.expand_icon = true
	main.refresh_button.add_theme_constant_override("icon_max_width",20)
	main.refresh_button.add_theme_constant_override("h_separation",7)

func apply_shop_layout(drawer: bool) -> void:
	shop_heading.get_node("ShopSymbol").visible = drawer
	shop_heading.get_node("GoldSymbol").visible = drawer
	shop_subtitle.visible = drawer
	main.setup_hint_label.visible = not drawer
	main.day_title.add_theme_font_size_override("font_size",18 if drawer else 16)
	main.selection_label.add_theme_font_size_override("font_size",15 if drawer else 14)
	main.refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if drawer else Control.SIZE_SHRINK_CENTER
	main.refresh_button.custom_minimum_size.y = 32 if drawer else 44
	main.get_node("HUD/DaySetupPanel/Margin/Content/Controls").add_theme_constant_override("separation",4 if drawer else 18)
	for button in main.card_buttons:
		button.get_node("ReferenceFace").visible = drawer
		for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:
			button.add_theme_color_override(state,Color.TRANSPARENT if drawer else Color("24180d"))
		if drawer:
			button.add_theme_font_size_override("font_size",1)
		else:
			main._apply_shop_card_style(button,false)

func update_offer(button: Button, card: OpeningCardDefinition, held: int, state: String) -> void:
	var face: Control = button.get_node("ReferenceFace")
	face.definition = card
	face.illustration = HandCardSlot._illustration_for(card.card_id)
	face.count = held
	face.state_text = state
	face.unavailable = button.disabled
	face.update_icons()
	for style in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	for color in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:
		button.add_theme_color_override(color,Color.TRANSPARENT)
	button.add_theme_font_size_override("font_size",1)

func show_settings() -> void:
	if settings_panel == null:
		settings_panel = PopupPanel.new()
		settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		main.add_child(settings_panel)
		var content := VBoxContainer.new()
		settings_panel.add_child(content)
		content.add_child(label("显示设置",20))
		var full := CheckButton.new()
		full.text = "全屏显示"
		full.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		full.toggled.connect(func(value: bool): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED))
		content.add_child(full)
		var close := Button.new()
		close.text = "关闭"
		close.pressed.connect(settings_panel.hide)
		content.add_child(close)
	settings_panel.popup_centered(Vector2i(260,140))

func icon(kind: String, width: float) -> Control:
	var item := Icon.new()
	item.kind = kind
	item.custom_minimum_size = Vector2(width,width)
	item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return item

func label(text: String, font_size: int) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",Color("f4e8cd"))
	return item

func spacer(row: HBoxContainer) -> void:
	var item := Control.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(item)

func panel_style() -> StyleBoxFlat:
	var style := Icon.box(Color("0b1724",0.98),Color("a28350"),3)
	style.content_margin_left = 5
	style.content_margin_right = 5
	return style

func status_margin(horizontal: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",horizontal)
	margin.add_theme_constant_override("margin_right",horizontal)
	return margin

func status_separator(parent: HBoxContainer) -> void:
	var line := ColorRect.new()
	line.name = "StatusDivider"
	line.color = Color("2b4052")
	line.custom_minimum_size = Vector2(1,22)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func status_symbol(kind: String, width: float) -> Control:
	var item := StatusSymbol.new()
	item.kind = kind
	item.custom_minimum_size = Vector2(width,width)
	item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return item

func style_status_button(button: Button, kind: String) -> Control:
	button.custom_minimum_size = Vector2(44,32)
	button.add_theme_font_size_override("font_size",1)
	for color in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:
		button.add_theme_color_override(color,Color.TRANSPARENT)
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover",Icon.box(Color("1a2c3e"),Color.TRANSPARENT,0))
	button.add_theme_stylebox_override("pressed",Icon.box(Color("253b50"),Color.TRANSPARENT,0))
	button.add_theme_stylebox_override("disabled",StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus",Icon.box(Color.TRANSPARENT,Color("8dacc4"),2))
	var symbol := status_symbol(kind,18)
	symbol.name = "StatusSymbol"
	button.add_child(symbol)
	symbol.size = Vector2(18,18)
	# 薄顶栏保留44像素横向点击宽度，符号垂直居中。
	symbol.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	symbol.position = Vector2(13,7)
	return symbol

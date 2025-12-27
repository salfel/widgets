package main

Style_Type :: enum {
	Rect,
}

Style_Manager :: struct {
	rect_styles: map[Rect_Style_Id]Rect_Style,
	current_id:  uint, // we're using only one id counter as it is not expected that it will ever overflow
}
g_style_manager: Style_Manager

style_manager_init :: proc(allocator := context.allocator) {
	g_style_manager.rect_styles = make(map[Rect_Style_Id]Rect_Style, allocator)
}

style_manager_destroy :: proc() {
	delete(g_style_manager.rect_styles)
}

Rect_Style_Id :: distinct uint
Rect_Style :: struct {
	width, height:      f32,
	background_color:   Color,
	changed_properties: bit_set[Rect_Property],
}
DEFAULT_RECT_STYLE :: Rect_Style {
	width              = 0,
	height             = 0,
	background_color   = Color{0, 0, 0, 0},
	changed_properties = {.Width, .Height, .Background_Color},
}
Rect_Property :: enum {
	Width,
	Height,
	Background_Color,
}

rect_style_init :: proc() -> Rect_Style_Id {
	id := Rect_Style_Id(g_style_manager.current_id)
	g_style_manager.rect_styles[id] = DEFAULT_RECT_STYLE

	g_style_manager.current_id += 1

	return id
}

rect_style_set_width :: proc(handle: Rect_Style_Id, width: f32) -> bool {
	style := style_get(handle) or_return
	style.width = width
	style.changed_properties += {.Width}

	return true
}

rect_style_set_height :: proc(handle: Rect_Style_Id, height: f32) -> bool {
	style := style_get(handle) or_return
	style.height = height
	style.changed_properties += {.Height}

	return true
}

rect_style_set_background_color :: proc(handle: Rect_Style_Id, background: Color) -> bool {
	style := style_get(handle) or_return
	style.background_color = background
	style.changed_properties += {.Background_Color}

	return true
}

style_set_width :: proc {
	rect_style_set_width,
}

style_set_height :: proc {
	rect_style_set_height,
}

style_set_background_color :: proc {
	rect_style_set_background_color,
}

style_get :: proc {
	style_get_rect,
}

@(private)
style_get_rect :: proc(handle: Rect_Style_Id) -> (^Rect_Style, bool) {
	return &g_style_manager.rect_styles[handle]
}

package main

import "core:slice"

Style_Id :: distinct int

Style_Type :: enum {
	Rect,
}

Style_Handle :: struct {
	id:   Style_Id,
	type: Style_Type,
}

Style_Manager :: struct {
	rect_styles: [dynamic]Style_Entry(Rect_Style),
}
g_style_manager: Style_Manager

Style_Entry :: struct(T: typeid) {
	data: T,
	id:   Style_Id,
}

Sizable_Style :: struct {
	size: [2]f32,
}

Rect_Style :: struct {
	using sizable:           Sizable_Style,
	background_color:        Color,
	rect_changed_properties: bit_set[Rect_Property],
}

Rect_Property :: enum {
	Size,
	Background_Color,
}

DEFAULT_RECT_STYLE := Rect_Style {
	size                    = [2]f32{0, 0},
	background_color        = Color{0, 0, 0, 0},
	rect_changed_properties = {.Size, .Background_Color},
}

rect_style_init :: proc() -> Style_Id {
	id := slice.last(g_style_manager.rect_styles[:]).id + 1 if len(g_style_manager.rect_styles) > 0 else 0
	append(&g_style_manager.rect_styles, Style_Entry(Rect_Style){DEFAULT_RECT_STYLE, id})

	return id
}

rect_style_destroy :: proc(style_id: Style_Id) {
	index, ok := style_manager_rect_style_index(style_id)

	if ok {
		ordered_remove(&g_style_manager.rect_styles, index)
	}
}

rect_style_set_background_color :: proc(style_id: Style_Id, color: Color) {
	rect_style, ok := style_manager_rect_style_get(style_id)

	if !ok || rect_style.background_color == color {
		return
	}

	rect_style.background_color = color
	rect_style.rect_changed_properties += {.Background_Color}
}

rect_style_set_size :: proc(style_id: Style_Id, size: [2]f32) {
	rect_style, ok := style_manager_rect_style_get(style_id)

	if !ok || rect_style.size == size {
		return
	}

	rect_style.size = size
	rect_style.rect_changed_properties += {.Size}
}

style_manager_rect_style_index :: proc(style_id: Style_Id) -> (int, bool) {
	return slice.binary_search_by(
		g_style_manager.rect_styles[:],
		Style_Entry(Rect_Style){id = style_id},
		proc(a, b: Style_Entry(Rect_Style)) -> slice.Ordering {
			if a.id < b.id {
				return .Less
			} else if a.id > b.id {
				return .Greater
			} else {
				return .Equal
			}
		},
	)
}

style_manager_rect_style_get :: proc(style_id: Style_Id) -> (rect_style: ^Rect_Style, ok: bool) {
	index := style_manager_rect_style_index(style_id) or_return

	return &g_style_manager.rect_styles[index].data, true
}

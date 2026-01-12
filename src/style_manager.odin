package main

import "base:intrinsics"

Style_Manager :: struct {
	rect_styles:       map[Rect_Style_Id]Rect_Style,
	text_field_styles: map[Text_Field_Style_Id]Text_Field_Style,
	current_id:        uint, // we're using only one id counter as it is not expected that it will ever overflow
}
g_style_manager: Style_Manager

style_manager_init :: proc(allocator := context.allocator) {
	g_style_manager.rect_styles = make(map[Rect_Style_Id]Rect_Style, allocator)
	g_style_manager.rect_styles[0] = DEFAULT_RECT_STYLE

	g_style_manager.text_field_styles = make(map[Text_Field_Style_Id]Text_Field_Style, allocator)
	g_style_manager.text_field_styles[0] = DEFAULT_TEXT_FIELD_STYLE

	g_style_manager.current_id = 1
}

style_manager_destroy :: proc() {
	for _, &style in g_style_manager.rect_styles {
		style_observer_destroy(&style.style_observer)
	}

	for _, &style in g_style_manager.text_field_styles {
		style_observer_destroy(&style.style_observer)
	}

	delete(g_style_manager.rect_styles)
	delete(g_style_manager.text_field_styles)
}

Style_Listener :: proc(data: rawptr)

Style_Observer :: struct {
	listeners: [dynamic]Handler(Style_Listener),
}

style_observer_init :: proc(style_observer: ^Style_Observer, allocator := context.allocator) {
	style_observer.listeners = make([dynamic]Handler(Style_Listener), allocator)
}

style_observer_destroy :: proc(style_observer: ^Style_Observer) {
	delete(style_observer.listeners)
}

style_observer_notify :: proc(style_observer: ^Style_Observer, style_id: Style_Id) {
	for listener in style_observer.listeners {
		listener.handler(listener.data)
	}
}

style_subscribe :: proc(
	style_id: $T,
	listener: Style_Listener,
	data: rawptr,
) -> bool where intrinsics.type_is_variant_of(Style_Id, T) {
	observer: ^Style_Observer = style_get(style_id) or_return
	append(&observer.listeners, Handler(Style_Listener){data = data, handler = listener})

	return true
}

// TODO: style_unlisten

Style_Id :: union {
	Rect_Style_Id,
	Text_Field_Style_Id,
}

Rect_Style_Id :: distinct uint
Rect_Style :: struct {
	using style_observer: Style_Observer,
	width, height:        f32,
	background_color:     Color,
	changed_properties:   bit_set[Rect_Property],
}
DEFAULT_RECT_ID :: Rect_Style_Id(0)
DEFAULT_RECT_STYLE :: Rect_Style {
	width              = 0,
	height             = 0,
	background_color   = TRANSPARENT,
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
	style_observer_init(&g_style_manager.rect_styles[id])

	g_style_manager.current_id += 1

	return id
}

Text_Field_Style_Id :: distinct uint
Text_Field_Style :: struct {
	using style_observer: Style_Observer,
	font_size:            f32,
	background_color:     Color,
	changed_properties:   bit_set[Text_Field_Property],
}
DEFAULT_TEXT_FIELD_ID :: Text_Field_Style_Id(0)
DEFAULT_TEXT_FIELD_STYLE :: Text_Field_Style {
	font_size        = 16,
	background_color = Color{0.2, 0.2, 0.2, 1.0},
}
Text_Field_Property :: enum {
	Font_Size,
	Background_Color,
}

text_field_style_init :: proc() -> Text_Field_Style_Id {
	id := Text_Field_Style_Id(g_style_manager.current_id)
	g_style_manager.text_field_styles[id] = DEFAULT_TEXT_FIELD_STYLE
	style_observer_init(&g_style_manager.text_field_styles[id])

	g_style_manager.current_id += 1

	return id
}

style_set_width :: proc(handle: $T, width: f32) -> bool where intrinsics.type_is_variant_of(Style_Id, T) {
	style := style_get(handle) or_return
	style.width = width
	style.changed_properties += {.Width}
	style_observer_notify(style, handle)

	return true
}

style_set_height :: proc(handle: $T, height: f32) -> bool where intrinsics.type_is_variant_of(Style_Id, T) {
	style := style_get(handle) or_return
	style.height = height
	style.changed_properties += {.Height}
	style_observer_notify(style, handle)

	return true
}

style_set_background_color :: proc(
	handle: $T,
	background: Color,
) -> bool where intrinsics.type_is_variant_of(Style_Id, T) {
	style := style_get(handle) or_return
	style.background_color = background
	style.changed_properties += {.Background_Color}
	style_observer_notify(style, handle)

	return true
}

style_set_font_size :: proc(handle: $T, font_size: f32) -> bool where intrinsics.type_is_variant_of(Style_Id, T) {
	style := style_get(handle) or_return
	style.font_size = font_size
	style.changed_properties += {.Font_Size}
	style_observer_notify(style, handle)

	return true
}

style_get :: proc {
	style_get_rect,
	style_get_text_field,
}

@(private)
style_get_rect :: proc(handle: Rect_Style_Id) -> (^Rect_Style, bool) {
	return &g_style_manager.rect_styles[handle]
}

@(private)
style_get_text_field :: proc(handle: Text_Field_Style_Id) -> (^Text_Field_Style, bool) {
	return &g_style_manager.text_field_styles[handle]
}

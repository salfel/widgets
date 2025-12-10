package main

import "core:fmt"
import "draw"

Text_Field :: struct {
	field: draw.Rect,
}

text_field_make :: proc(allocator := context.allocator) -> (widget: ^Widget, ok := true) #optional_ok {
	widget = widget_make(allocator)
	widget.type = .Text_Field

	widget.allow_children = false
	widget.focusable = true

	widget.draw = text_field_draw
	widget.destroy = text_field_destroy
	widget.recalculate_mp = text_field_recalculate_mp

	widget.data = Text_Field {
		field = draw.rect_make(),
	}

	return
}

text_field_destroy :: proc(widget: ^Widget) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))

	draw.rect_destroy(&text_field.field)
}

text_field_draw :: proc(widget: ^Widget, app_context: ^App_Context, depth: i32 = 1) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))

	draw.rect_draw(&text_field.field)
}

text_field_recalculate_mp :: proc(widget: ^Widget, app_context: ^App_Context) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))

	text_field.field.mp = calculate_mp2({200, 200}, {0, 0}, app_context.window.size)
}

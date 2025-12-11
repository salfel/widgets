package main

import "core:fmt"
import "core:strings"
import text "core:text/edit"
import "draw"
import gl "vendor:OpenGL"

Text_Field :: struct {
	state:   text.State,
	builder: strings.Builder,
	field:   draw.Rect,
	text:    draw.Text,
}

text_field_make :: proc(allocator := context.allocator) -> (widget: ^Widget, ok := true) #optional_ok {
	widget = widget_make(allocator)
	widget.type = .Text_Field

	widget.allow_children = false
	widget.focusable = true

	widget.draw = text_field_draw
	widget.destroy = text_field_destroy
	widget.recalculate_mp = text_field_recalculate_mp
	widget.key = text_field_key

	widget.layout.style.size.x = layout_constraint_make(200)
	widget.layout.style.size.y = layout_constraint_make(200)

	widget.data = Text_Field {
		field = draw.rect_make(),
		text  = draw.text_make("", "Sans", 96, {1.0, 1.0, 1.0, 1.0}),
	}

	text_field := (&widget.data.(Text_Field))

	text_field.builder = strings.builder_make(context.allocator)
	text.init(&text_field.state, context.allocator, context.allocator)
	text.begin(&text_field.state, 0, &text_field.builder)

	return
}

text_field_destroy :: proc(widget: ^Widget) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))

	draw.rect_destroy(&text_field.field)
	draw.text_destroy(&text_field.text)

	strings.builder_destroy(&text_field.builder)
	text.destroy(&text_field.state)
}

text_field_draw :: proc(widget: ^Widget, app_context: ^App_Context, depth: i32 = 1) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))

	gl.ColorMask(true, true, true, true)
	gl.StencilMask(0x00)
	gl.StencilFunc(gl.EQUAL, 2 - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.KEEP)

	draw.rect_draw(&text_field.field)
	draw.text_draw(&text_field.text)
}

text_field_key :: proc(widget: ^Widget, key: rune, app_context: ^App_Context) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))

	text.input_rune(&text_field.state, key)
	draw.text_set_content(&text_field.text, string(text_field.state.builder.buf[:]))
	text_field.text.mp = calculate_mp2(
		{f32(text_field.text.pref_size.x), f32(text_field.text.pref_size.y)},
		{0, 0},
		app_context.window.size,
	)
}

text_field_recalculate_mp :: proc(widget: ^Widget, app_context: ^App_Context) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))

	text_field.field.mp = calculate_mp2({200, 200}, {0, 0}, app_context.window.size)
	text_field.text.mp = calculate_mp2(
		{f32(text_field.text.pref_size.x), f32(text_field.text.pref_size.y)},
		{0, 0},
		app_context.window.size,
	)
}

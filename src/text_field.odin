package main

import "core:fmt"
import "core:strings"
import text "core:text/edit"
import gl "vendor:OpenGL"

Text_Field :: struct {
	state:   text.State,
	builder: strings.Builder,
	field:   Rect,
	text:    Text,
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
		field = rect_make({100, 0}, {0.2, 0.2, 0.2, 1.0}),
		text  = text_make("", "Sans", 96, {1.0, 1.0, 1.0, 1.0}),
	}

	text_field := (&widget.data.(Text_Field))

	append(&widget.layout.children, &text_field.field.layout)
	append(&text_field.field.layout.children, &text_field.text.layout)

	text_field.builder = strings.builder_make(context.allocator)
	text.init(&text_field.state, context.allocator, context.allocator)
	text.begin(&text_field.state, 0, &text_field.builder)

	return
}

text_field_destroy :: proc(widget: ^Widget) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))

	rect_destroy(&text_field.field)
	text_destroy(&text_field.text)

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

	text_field.field.mp = calculate_mp(text_field.field.layout, app_context)
	text_field.text.mp = calculate_mp(text_field.text.layout, app_context)

	rect_draw(&text_field.field)
	text_draw(&text_field.text)
}

text_field_key :: proc(widget: ^Widget, key: Key, modifiers: Modifiers, app_context: ^App_Context) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))

	#partial switch key.type {
	case .Char:
		if .Ctrl in modifiers {
			switch key.char {
			case 'a':
				text.perform_command(&text_field.state, .Select_All)
			case 'c':
				text.perform_command(&text_field.state, .Copy)
			case 'x':
				text.perform_command(&text_field.state, .Cut)
			case 'v':
				text.perform_command(&text_field.state, .Paste)
			}
		} else {
			text.input_rune(&text_field.state, key.char)
		}
	case .Backspace:
		text.perform_command(&text_field.state, .Backspace)
	case .Delete:
		text.perform_command(&text_field.state, .Delete)
	case .Left:
		text.perform_command(&text_field.state, .Left)
	case .Right:
		text.perform_command(&text_field.state, .Right)
	case .Escape:
		app_context.input.focused = 0
		widget.focused = false
	}

	text_set_content(&text_field.text, string(text_field.state.builder.buf[:]))
	app_context.renderer.dirty = true
}

text_field_recalculate_mp :: proc(widget: ^Widget, app_context: ^App_Context) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))
}

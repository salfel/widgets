package main

import "core:fmt"
import "core:strings"
import text "core:text/edit"
import gl "vendor:OpenGL"

Text_Field :: struct {
	state:          text.State,
	builder:        strings.Builder,

	// shapes
	field, cursor:  Rect,
	text:           Text,
	pending_update: bit_set[Text_Field_Shape],
}
Text_Field_Shape :: enum {
	Field,
	Cursor,
	Text,
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

	widget.layout.style.padding = sides_make(20)

	font_size: f32 = 48
	content := "helloworld"

	widget.data = Text_Field {
		field  = rect_make({600, 0}, {0.2, 0.2, 0.2, 1.0}),
		text   = text_make(content, "Sans", font_size, WHITE),
		cursor = rect_make({1, 96}, WHITE),
	}

	text_field := (&widget.data.(Text_Field))

	append(&widget.layout.children, &text_field.field.layout)
	append(&text_field.field.layout.children, &text_field.text.layout)
	append(&text_field.field.layout.children, &text_field.cursor.layout)

	text_field.cursor.layout.behaviour = .Absolute
	text_field.field.layout.scroll.stick_end = true

	text_field.builder = strings.builder_make(context.allocator)
	strings.write_string(&text_field.builder, content)

	text.init(&text_field.state, context.allocator, context.allocator)
	text.begin(&text_field.state, 0, &text_field.builder)
	text.move_to(&text_field.state, .End)

	text_field_update_cursor(text_field)

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
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.KEEP)

	for shape in text_field.pending_update {
		switch shape {
		case .Field:
			rect_recalculate_mp(&text_field.field, app_context)
		case .Cursor:
			rect_recalculate_mp(&text_field.cursor, app_context)
		case .Text:
			text_recalculate_mp(&text_field.text, app_context)
		}
	}
	text_field.pending_update = {}

	rect_draw(&text_field.field)
	gl.Enable(gl.SCISSOR_TEST)
	gl.Scissor(
		i32(text_field.field.layout.position.x),
		i32(app_context.window.size.y - text_field.field.layout.position.y - text_field.field.layout.size.y),
		i32(text_field.field.layout.size.x),
		i32(text_field.field.layout.size.y),
	)
	text_draw(&text_field.text)
	gl.Disable(gl.SCISSOR_TEST)
	rect_draw(&text_field.cursor)
}

text_field_key :: proc(widget: ^Widget, key: Key, modifiers: Modifiers, app_context: ^App_Context) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))

	update_cursor: bool = false
	update_text: bool = false

	#partial switch key.type {
	case .Char:
		if .Ctrl in modifiers {
			switch key.char {
			case 'a':
				text.perform_command(&text_field.state, .Select_All)
				update_cursor = true
			// clipboad not implemented yet
			case 'c':
				text.perform_command(&text_field.state, .Copy)
			case 'x':
				text.perform_command(&text_field.state, .Cut)
			case 'v':
				text.perform_command(&text_field.state, .Paste)
				update_text = true
				update_cursor = true
			}
		} else {
			text.input_rune(&text_field.state, key.char)
			update_cursor = true
			update_text = true
		}
	case .Backspace:
		text.perform_command(&text_field.state, .Backspace)
		update_cursor = true
		update_text = true
	case .Delete:
		text.perform_command(&text_field.state, .Delete)
		update_cursor = true
		update_text = true
	case .Left:
		text.perform_command(&text_field.state, .Left)
		update_cursor = true
	case .Right:
		text.perform_command(&text_field.state, .Right)
		update_cursor = true
	case .Escape:
		app_context.input.focused = 0
		widget.focused = false
	}

	if update_text {
		text_set_content(&text_field.text, strings.to_string(text_field.builder))
		text_field.pending_update += {.Text}
	}
	if update_cursor {
		text_field_update_cursor(text_field)
		text_field.pending_update += {.Cursor}
	}

	app_context.renderer.dirty = true
}

text_field_recalculate_mp :: proc(widget: ^Widget, app_context: ^App_Context) {
	text_field, ok := (&widget.data.(Text_Field))
	assert(ok, fmt.tprint("invalid widget type, expected Text_Field, got:", widget.type))

	if text_field.field.layout.dirty {
		text_field.pending_update += {.Field}
	}

	if text_field.text.layout.dirty {
		text_field.pending_update += {.Text}
	}

	if text_field.cursor.layout.dirty {
		text_field.pending_update += {.Cursor}
	}
}

text_field_update_cursor :: proc(text_field: ^Text_Field) {
	cursor_pos, height := font_get_cursor_pos(&text_field.text.font, i32(text_field.state.selection[0]))

	text_field.cursor.layout.style.position = sides_make(f32(cursor_pos.x), 0, f32(cursor_pos.y), 0)
	text_field.cursor.layout.style.size.x = layout_constraint_make(1)
	text_field.cursor.layout.style.size.y = layout_constraint_make(f32(height))

	return
}

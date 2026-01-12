package main

import "core:fmt"
import "core:strings"
import text "core:text/edit"
import gl "vendor:OpenGL"

Text_Field :: struct {
	style:                    Text_Field_Style_Id,

	// text state
	state:                    text.State,
	builder:                  strings.Builder,

	// shapes
	field, cursor, selection: Rect, // TODO: maybe inline those in text_field
	text:                     Text,
	pending_update:           bit_set[Text_Field_Shape],
}
Text_Field_Shape :: enum {
	Field,
	Cursor,
	Text,
	Selection,
}

text_field_make :: proc(
	style: Text_Field_Style_Id = 0,
	allocator := context.allocator,
) -> (
	widget: ^Widget,
	ok := true,
) #optional_ok {
	widget = widget_make(allocator)
	widget.type = .Text_Field

	widget.allow_children = false
	widget.focusable = true

	widget.draw = text_field_draw
	widget.destroy = text_field_destroy
	widget.recalculate_mp = text_field_recalculate_mp
	widget.key = text_field_key

	widget.layout.style.padding = sides_make(20)

	content := "helloworld"

	widget.data = Text_Field{}
	text_field := (&widget.data.(Text_Field))

	text_field.style = style
	style_subscribe(style, text_field_style_changed, text_field)

	style := style_get(style) or_return

	text_field.text = text_make(content, "Sans", style.font_size, WHITE)

	field_style := rect_style_init()
	style_set_width(field_style, 600)
	style_set_height(field_style, 0)
	style_set_background_color(field_style, style.background_color)
	rect_init(&text_field.field, field_style)

	cursor_style := rect_style_init()
	style_set_width(cursor_style, 1)
	style_set_height(cursor_style, 96)
	style_set_background_color(cursor_style, WHITE)
	rect_init(&text_field.cursor, cursor_style)

	selection_style := rect_style_init()
	style_set_width(selection_style, 0)
	style_set_height(selection_style, 0)
	style_set_background_color(selection_style, BLUE)
	rect_init(&text_field.selection, selection_style)

	append(&widget.layout.children, &text_field.field.layout)
	append(&text_field.field.layout.children, &text_field.text.layout)
	append(&text_field.field.layout.children, &text_field.cursor.layout)
	append(&text_field.field.layout.children, &text_field.selection.layout)

	text_field.cursor.layout.behaviour = .Absolute
	text_field.selection.layout.behaviour = .Absolute

	text_field.cursor.layout.on_compute = {
		data = text_field,
		handler = proc(layout: ^Layout, data: rawptr) {
			text_field := cast(^Text_Field)data

			diff := text_field.cursor.layout.style.position.left - text_field.field.layout.scroll.position[.Horizontal]

			if diff > text_field.field.layout.size.x {
				text_field.field.layout.scroll.position[.Horizontal] += diff - text_field.field.layout.size.x
				text_field.pending_update += {.Text}
			} else if diff < 0 {
				text_field.field.layout.scroll.position[.Horizontal] += diff
				text_field.pending_update += {.Text}
			}
		},
	}

	text_set_wrap(&text_field.text, .WRAP_NONE)

	text_field.builder = strings.builder_make(context.allocator)
	strings.write_string(&text_field.builder, content)

	text.init(&text_field.state, context.allocator, context.allocator)
	text.begin(&text_field.state, 0, &text_field.builder)
	text.move_to(&text_field.state, .End)

	text_field.state.set_clipboard = proc(user_data: rawptr, text: string) -> (ok: bool) {
		app_context := cast(^App_Context)user_data

		clipboard_copy(text, app_context)
		return true
	}

	text_field.state.get_clipboard = proc(user_data: rawptr) -> (text: string, ok: bool) {
		app_context := cast(^App_Context)user_data

		return clipboard_paste(app_context), true
	}

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

	// temporary
	if text_field.state.clipboard_user_data == nil {
		text_field.state.clipboard_user_data = app_context
	}

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
		case .Selection:
			rect_recalculate_mp(&text_field.selection, app_context)
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
	rect_draw(&text_field.selection)
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
				update_text = true
				update_cursor = true
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

text_field_style_changed :: proc(data: rawptr) {
	text_field := cast(^Text_Field)data
	style, ok := style_get(text_field.style)

	for property in style.changed_properties {
		switch property {
		case .Font_Size:
		// TODO
		case .Background_Color:
			style_set_background_color(text_field.field.style_id, style.background_color)
		}
	}

	// TODO: register wl callback
}

text_field_update_cursor :: proc(text_field: ^Text_Field) {
	start, end := text_field.state.selection[1], text_field.state.selection[0]

	if start == end {
		cursor_pos, height := font_get_cursor_pos(&text_field.text.font, i32(start))

		text_field.cursor.layout.style.position = sides_make(f32(cursor_pos.x), 0, f32(cursor_pos.y), 0)
		text_field.cursor.layout.style.size.x = layout_constraint_make(1)
		text_field.cursor.layout.style.size.y = layout_constraint_make(f32(height))

		text_field.selection.layout.style.size = {layout_constraint_make(0), layout_constraint_make(0)}

		text_field.pending_update += {.Selection}

		return
	}

	text_field.cursor.layout.style.size = {layout_constraint_make(0), layout_constraint_make(0)}

	start_pos, height := font_get_cursor_pos(&text_field.text.font, i32(start))
	end_pos, _ := font_get_cursor_pos(&text_field.text.font, i32(end))

	text_field.selection.layout.style.position = sides_make(f32(start_pos.x), 0, f32(start_pos.y), 0)
	text_field.selection.layout.style.size = {
		layout_constraint_make(f32(end_pos.x - start_pos.x)),
		layout_constraint_make(f32(height)),
	}

	text_field.pending_update += {.Selection}
}

package main

import "core:container/queue"

Input :: struct {
	focused:  WidgetId,
	pointer:  struct {
		position: [2]f32,
		buttons:  Pointer_Buttons,
	},
	keyboard: struct {
		chars:     queue.Queue(rune),
		modifiers: Modifiers,
	},
}

input_init :: proc(input: ^Input, allocator := context.allocator) {
	queue.init(&input.keyboard.chars, allocator = allocator)
}

input_destroy :: proc(input: ^Input) {
	queue.destroy(&input.keyboard.chars)
}

input_handle_pointer_button :: proc(button: Pointer_Button, pressed: bool, app_context: ^App_Context) {
	was_pressed := Pointer_Buttons{button} <= app_context.input.pointer.buttons
	if pressed do app_context.input.pointer.buttons += {button}
	else do app_context.input.pointer.buttons -= {button}

	if !was_pressed || pressed do return

	_handle_click(app_context.widget_manager.viewport, app_context.input.pointer.position, app_context)
}

@(private)
_handle_click :: proc(widget: ^Widget, position: [2]f32, app_context: ^App_Context) {
	if widget.on_click.handler != nil {
		widget.on_click.handler(widget, position, widget.on_click.data, app_context)
	}

	if widget.focusable {
		if old_focused, ok := app_context.widget_manager.widgets[app_context.input.focused]; ok {
			old_focused.focused = false
		}

		app_context.input.focused = widget.id
	}

	for child in widget.children {
		if widget_contains_point(widget, app_context.input.pointer.position) {
			_handle_click(child, position, app_context)
		}
	}
}

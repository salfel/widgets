package main

import "core:container/queue"

Input :: struct {
	pointer:  struct {
		position: [2]f32,
		buttons:  Pointer_Buttons,
	},
	keyboard: struct {
		chars:     queue.Queue(rune),
		modifiers: Modifiers,
	},
}

input_handle_pointer_button :: proc(button: Pointer_Button, pressed: bool, app_context: ^App_Context) {
	was_pressed := Pointer_Buttons{button} <= app_context.input.pointer.buttons
	if pressed do app_context.input.pointer.buttons += {button}
	else do app_context.input.pointer.buttons -= {button}

	if !was_pressed || pressed do return

	// handle click
	for _, widget in app_context.widget_manager.widgets {
		if widget_contains_point(widget, app_context.input.pointer.position) && widget.on_click.handler != nil {
			widget.on_click.handler(widget, app_context.input.pointer.position, widget.on_click.data, app_context)
		}
	}
}

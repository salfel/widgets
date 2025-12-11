package main

Input :: struct {
	focused:  WidgetId,
	pointer:  struct {
		position: [2]f32,
		buttons:  Pointer_Buttons,
	},
	keyboard: struct {
		modifiers: Modifiers,
	},
}

input_handle_pointer_button :: proc(button: Pointer_Button, pressed: bool, app_context: ^App_Context) {
	was_pressed := Pointer_Buttons{button} <= app_context.input.pointer.buttons
	if pressed do app_context.input.pointer.buttons += {button}
	else do app_context.input.pointer.buttons -= {button}

	if !was_pressed || pressed do return

	if old_focused, ok := widget_get(app_context.input.focused, &app_context.widget_manager); ok {
		old_focused.focused = false
	}
	found := _input_handle_click(app_context.widget_manager.viewport, app_context.input.pointer.position, app_context)
	if !found {
		app_context.input.focused = 0
	}
}

@(private)
_input_handle_click :: proc(widget: ^Widget, position: [2]f32, app_context: ^App_Context) -> bool {
	if widget.on_click.handler != nil {
		widget.on_click.handler(widget, position, widget.on_click.data, app_context)
	}

	if widget.focusable {
		app_context.input.focused = widget.id

		return true
	}

	found := false
	for child in widget.children {
		if widget_contains_point(child, app_context.input.pointer.position) {
			found |= _input_handle_click(child, position, app_context)
		}
	}

	return found
}

input_handle_key :: proc(char: rune, app_context: ^App_Context) {
	widget, ok := widget_get(app_context.input.focused, &app_context.widget_manager)
	if !ok || widget.key == nil {
		return
	}

	widget->key(char, app_context)
}

package main

import "core:container/queue"
import wl "lib:wayland"
import gl "vendor:OpenGL"

Event_Manager :: struct {
	events: queue.Queue(Event),
}

Event :: struct {
	type: Event_Type,
	data: union {
		[2]f32,
		Pointer_Button,
		Modifier,
		rune,
	},
}

Event_Type :: enum {
	Window_Close,
	Window_Resize,
	Pointer_Press,
	Pointer_Release,
	Pointer_Move,
	Keyboard_Modifier_Activated,
	Keyboard_Modifier_Deactivated,
	Keyboard_Char,
}


event_manager_init :: proc(event_manager: ^Event_Manager, allocator := context.allocator) {
	queue.init(&event_manager.events, allocator = allocator)
}

event_manager_destroy :: proc(event_manager: ^Event_Manager) {
	queue.destroy(&event_manager.events)
}

event_register :: proc(event: Event, app_context: ^App_Context) {
	queue.push(&app_context.event_manager.events, event)

	wl_register_callback(&app_context.window)
}

handle_events :: proc(app_context: ^App_Context) {
	for queue.len(app_context.event_manager.events) != 0 {
		event := queue.pop_front(&app_context.event_manager.events)

		switch event.type {
		case .Window_Close:
			app_context.renderer.exit = true
		case .Window_Resize:
			size, ok := event.data.([2]f32)
			assert(ok, "Invalid data for window resize event.")
			app_context.window.size = size

			wl.egl_window_resize(
				app_context.window.egl.window,
				int(app_context.window.size.x),
				int(app_context.window.size.y),
				0,
				0,
			)
			gl.Viewport(0, 0, i32(app_context.window.size.x), i32(app_context.window.size.y))

			for _, widget in app_context.widget_manager.widgets {
				widget->recalculate_mp(app_context)
			}

			app_context.widget_manager.viewport.layout.style.size.y = layout_constraint_make(app_context.window.size.y)
			app_context.widget_manager.viewport->recalculate_mp(app_context)
		case .Pointer_Move:
			position, ok := event.data.([2]f32)
			assert(ok, "Invalid data for pointer move event.")

			app_context.input.pointer.position = position
		case .Pointer_Press, .Pointer_Release:
			button, ok := event.data.(Pointer_Button)
			assert(ok, "Invalid data for pointer button event.")

			input_handle_pointer_button(button, event.type == .Pointer_Press, app_context)
		case .Keyboard_Modifier_Activated:
			modifier, ok := event.data.(Modifier)
			assert(ok, "Invalid data for keyboard modifier activated event.")

			app_context.input.keyboard.modifiers += {modifier}
		case .Keyboard_Modifier_Deactivated:
			modifier, ok := event.data.(Modifier)
			assert(ok, "Invalid data for keyboard modifier deactivated event.")

			app_context.input.keyboard.modifiers -= {modifier}
		case .Keyboard_Char:
			char, ok := event.data.(rune)
			assert(ok, "Invalid data for keyboard char event.")

			queue.push(&app_context.input.keyboard.chars, char)
		}
	}
}

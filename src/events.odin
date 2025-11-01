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
	},
}

Event_Type :: enum {
	Window_Close,
	Window_Resize,
	Pointer_Button,
	Pointer_Move,
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

		#partial switch event.type {
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

			app_context.widget_manager.viewport->recalculate_mp(app_context)
		case .Pointer_Move:
			position, ok := event.data.([2]f32)
			assert(ok, "Invalid data for pointer move event.")

			app_context.input.pointer.position = position
		case .Pointer_Button:
			button, ok := event.data.(Pointer_Button)
			assert(ok, "Invalid data for pointer button event.")

			if button != .Left do return

			position := app_context.input.pointer.position

			for _, widget in app_context.widget_manager.widgets {
				if widget_contains_point(widget, position) && widget.on_click != nil {
					widget.on_click(widget, position, app_context)
				}
			}
		}
	}
}

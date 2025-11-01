package main

import "base:intrinsics"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:math"
import wl "lib:wayland"
import gl "vendor:OpenGL"
import "vendor:egl"

Renderer :: struct {
	ctx:              runtime.Context,
	widget_id:        WidgetId,
	viewport:         ^Widget,
	widgets:          map[WidgetId]^Widget,
	dirty:            bool,
	window_state:     Window_State,
	events:           queue.Queue(Event),
	pointer_position: [2]f32,
	exit:             bool,
}

Window_State :: struct {
	wl:       Wayland_State,
	egl:      Egl_State,
	renderer: ^Renderer,
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

global_ctx: runtime.Context
window_size: [2]f32

renderer_init :: proc(renderer: ^Renderer, title, app_id: cstring, allocator := context.allocator) {
	renderer.ctx = context
	global_ctx = context

	wl_init(renderer, title, app_id)
	egl_init(&renderer.window_state)

	renderer.viewport = box_make()
	renderer.viewport.id = -1

	renderer.widget_id = 0
	renderer.dirty = true
	renderer.window_state.renderer = renderer
}

renderer_loop :: proc(renderer: ^Renderer) {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	egl.SwapBuffers(renderer.window_state.egl.display, renderer.window_state.egl.surface)

	for wl.display_dispatch(renderer.window_state.wl.display) != -1 && !renderer.exit {
		renderer_handle_events(renderer)
	}

	renderer_destroy(renderer)
}

renderer_render :: proc(renderer: ^Renderer) {
	gl.ClearColor(0, 0, 0, 0)
	gl.ClearStencil(0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	if renderer.dirty {
		layout_compute(&renderer.viewport.layout, window_size.x)
		layout_arrange(&renderer.viewport.layout)

		for _, widget in renderer.widgets {
			if widget.layout.result.dirty {
				widget->recalculate_mp()
			}
		}

		renderer.dirty = false
	}

	renderer.viewport->draw(1)

	egl.SwapBuffers(renderer.window_state.egl.display, renderer.window_state.egl.surface)
}

renderer_destroy :: proc(renderer: ^Renderer) {
	for _, widget in renderer.widgets {
		delete(widget.layout.children)
		delete(widget.children)
		free(widget)
	}
	delete(renderer.window_state.wl.keyboard_state.chars)
	delete(renderer.widgets)
	delete(renderer.viewport.children)
	delete(renderer.viewport.layout.children)
	free(renderer.viewport)

	queue.destroy(&renderer.events)
}

renderer_handle_click :: proc(renderer: ^Renderer) {
}

renderer_register_click :: proc(renderer: ^Renderer, widget: WidgetId, onclick: On_Click) -> bool {
	widget := renderer_unsafe_get_widget(renderer, widget) or_return
	widget.on_click = onclick

	return true
}

renderer_register_widget :: proc(renderer: ^Renderer, widget: ^Widget, viewport_child := true) -> WidgetId {
	id := WidgetId(renderer.widget_id)
	renderer.widget_id += 1

	renderer.widgets[id] = widget

	widget.id = id

	if viewport_child {
		append(&renderer.viewport.children, widget)
		append(&renderer.viewport.layout.children, &widget.layout)
		widget.parent = renderer.viewport.id
	}

	return id
}

renderer_register_child :: proc(
	renderer: ^Renderer,
	parent_id: WidgetId,
	child: ^Widget,
) -> (
	child_id: WidgetId,
	ok: bool,
) {
	child_id = renderer_register_widget(renderer, child, false)

	child := renderer_unsafe_get_widget(renderer, child_id) or_return
	parent := renderer_unsafe_get_widget(renderer, parent_id) or_return

	widget_add_child(parent, child)

	return
}

@(private)
renderer_unsafe_get_widget :: proc(renderer: ^Renderer, id: WidgetId) -> (^Widget, bool) {
	return renderer.widgets[id]
}

renderer_add_event :: proc(renderer: ^Renderer, event: Event) {
	queue.push(&renderer.events, event)

	register_callback(&renderer.window_state)
}

renderer_handle_events :: proc(renderer: ^Renderer) {
	for queue.len(renderer.events) != 0 {
		event := queue.pop_front(&renderer.events)

		#partial switch event.type {
		case .Window_Close:
			renderer.exit = true
		case .Window_Resize:
			size, ok := event.data.([2]f32)
			assert(ok, "Invalid data for window resize event.")
			window_size = size

			wl.egl_window_resize(renderer.window_state.egl.window, int(window_size.x), int(window_size.y), 0, 0)
			gl.Viewport(0, 0, i32(window_size.x), i32(window_size.y))

			for _, widget in renderer.widgets {
				widget->recalculate_mp()
			}

			renderer.viewport->recalculate_mp()
		case .Pointer_Move:
			position, ok := event.data.([2]f32)
			assert(ok, "Invalid data for pointer move event.")

			renderer.pointer_position = position
		case .Pointer_Button:
			button, ok := event.data.(Pointer_Button)
			assert(ok, "Invalid data for pointer button event.")

			if button != .Left do return

			position := renderer.pointer_position

			for _, widget in renderer.widgets {
				if widget_contains_point(widget, position) && widget.on_click != nil {
					widget.on_click(widget, position)
				}
			}
		}
	}
}

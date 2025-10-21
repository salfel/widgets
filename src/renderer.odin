package main

import wl "../lib/wayland"
import "base:runtime"
import "core:fmt"
import gl "vendor:OpenGL"
import "vendor:egl"


Renderer :: struct {
	ctx:            runtime.Context,
	widget_id:      WidgetId,
	root_widget:    ^Widget,
	widgets:        [dynamic]^Widget,
	wl_state:       Wayland_State,
	egl_state:      Egl_State,
	libdecor_state: Libdecor_State,
	window_size:    [2]f32,
}

g_Renderer: Renderer

renderer_init :: proc(app_id, title: cstring) {
	g_Renderer.ctx = context

	wayland_init()
	egl_init()
	libdecor_init(app_id, title)
}

renderer_loop :: proc() {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	for wl.display_dispatch_pending(g_Renderer.wl_state.display) != -1 {
		gl.ClearColor(0, 0, 0, 0)
		gl.ClearStencil(0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		layout_compute(&g_Renderer.root_widget.layout, g_Renderer.window_size.x)
		layout_arrange(&g_Renderer.root_widget.layout)

		renderer_draw_widget(g_Renderer.root_widget.id, 1)

		egl.SwapBuffers(g_Renderer.egl_state.display, g_Renderer.egl_state.surface)
	}
}

renderer_draw_widget :: proc(widget: WidgetId, depth: i32) -> bool {
	widget := renderer_unsafe_get_widget(widget) or_return

	switch widget.type {
	case .Box, .Block:
		box_draw(widget, depth)
	case .Text:
		text_draw(widget, depth)
	}

	return true
}

renderer_register_widget :: proc(widget: Widget) -> WidgetId {
	widget := new_clone(widget)

	append(&g_Renderer.widgets, widget)

	id := WidgetId(g_Renderer.widget_id)
	g_Renderer.widget_id += 1

	if id == 0 {
		g_Renderer.root_widget = widget
	}

	widget.id = id

	return id
}

renderer_register_child :: proc(parent_id: WidgetId, child: Widget) -> (child_id: WidgetId, ok: bool) {
	child_id = renderer_register_widget(child)

	child := renderer_unsafe_get_widget(child_id) or_return
	parent := renderer_unsafe_get_widget(parent_id) or_return

	append(&parent.children, child_id)
	append(&parent.layout.children, &child.layout)
	child.parent = parent_id

	return
}

@(private)
renderer_unsafe_get_widget :: proc(id: WidgetId) -> (^Widget, bool) {
	for &widget in &g_Renderer.widgets {
		if widget.id == id {
			return widget, true
		}
	}

	return nil, false
}

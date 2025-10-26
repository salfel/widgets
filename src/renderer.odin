package main

import wl "../lib/wayland"
import "base:runtime"
import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"
import "vendor:egl"


Renderer :: struct {
	ctx:         runtime.Context,
	widget_id:   WidgetId,
	viewport:    Widget,
	widgets:     [dynamic]^Widget,
	wl_state:    Wayland_State,
	egl_state:   Egl_State,
	window_size: [2]f32,
	dirty:       bool,
	exit:        bool,
}

g_Renderer: Renderer

renderer_init :: proc(app_id, title: cstring, allocator := context.allocator) {
	g_Renderer.ctx = context

	wayland_init()
	egl_init()

	g_Renderer.viewport = viewport_make(allocator)
	g_Renderer.viewport.id = -1

	g_Renderer.widget_id = 0
	g_Renderer.dirty = true
	g_Renderer.exit = false
}

renderer_loop :: proc() {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	egl.SwapBuffers(g_Renderer.egl_state.display, g_Renderer.egl_state.surface)

	for wl.display_dispatch(g_Renderer.wl_state.display) != -1 && !g_Renderer.exit {}

	renderer_destroy()
}

renderer_render :: proc() {
	gl.ClearColor(0, 0, 0, 0)
	gl.ClearStencil(0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	if g_Renderer.dirty {
		layout_compute(&g_Renderer.viewport.layout, g_Renderer.window_size.x)
		layout_arrange(&g_Renderer.viewport.layout)

		g_Renderer.dirty = false
	}

	renderer_handle_click()

	viewport_draw(&g_Renderer.viewport)

	egl.SwapBuffers(g_Renderer.egl_state.display, g_Renderer.egl_state.surface)
}

renderer_destroy :: proc() {
	for widget in g_Renderer.widgets {
		delete(widget.layout.children)
		delete(widget.children)
		free(widget)
	}
	delete(g_Renderer.wl_state.keyboard_state.chars)
	delete(g_Renderer.widgets)
	delete(g_Renderer.viewport.children)
	delete(g_Renderer.viewport.layout.children)
}

renderer_handle_click :: proc() {
	clicked := Pointer_Buttons{.Left} <= g_Renderer.wl_state.pointer_state.clicked
	if !clicked {
		return
	}

	g_Renderer.wl_state.pointer_state.clicked -= Pointer_Buttons{.Left}

	position := g_Renderer.wl_state.pointer_state.position

	for &widget in &g_Renderer.widgets {
		if widget_contains_point(widget, position) && widget.onclick != nil {
			widget.onclick(widget, position)
		}
	}
}

renderer_register_click :: proc(widget: WidgetId, onclick: On_Click) -> bool {
	widget := renderer_unsafe_get_widget(widget) or_return
	widget.onclick = onclick

	return true
}

renderer_draw_widget :: proc(widget: WidgetId, depth: i32) -> bool {
	widget := renderer_unsafe_get_widget(widget) or_return

	switch widget.type {
	case .Box, .Block:
		box_draw(widget, depth)
	case .Text:
		text_draw(widget, depth)
	case .Viewport:
		assert(false, "Viewport should never be drawn")
	}

	return true
}

renderer_register_widget :: proc(widget: Widget, viewport_child := true) -> WidgetId {
	widget := new_clone(widget)

	append(&g_Renderer.widgets, widget)

	id := WidgetId(g_Renderer.widget_id)
	g_Renderer.widget_id += 1

	widget.id = id

	if viewport_child {
		append(&g_Renderer.viewport.children, id)
		append(&g_Renderer.viewport.layout.children, &widget.layout)
		widget.parent = g_Renderer.viewport.id
	}

	return id
}

renderer_register_child :: proc(parent_id: WidgetId, child: Widget) -> (child_id: WidgetId, ok: bool) {
	child_id = renderer_register_widget(child, false)

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

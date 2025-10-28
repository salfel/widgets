package main

import wl "../lib/wayland"
import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"
import "vendor:egl"

Renderer :: struct {
	ctx:          runtime.Context,
	widget_id:    WidgetId,
	viewport:     ^Box,
	widgets:      map[WidgetId]Widget_Storage,
	dirty:        bool,
	window_state: Window_State,
}

Window_State :: struct {
	wl:       Wayland_State,
	egl:      Egl_State,
	exit:     bool,
	renderer: ^Renderer,
}

global_ctx: runtime.Context
window_size: [2]f32

renderer_init :: proc(renderer: ^Renderer, title, app_id: cstring, allocator := context.allocator) {
	renderer.ctx = context
	global_ctx = context

	wl_init(&renderer.window_state, title, app_id)
	egl_init(&renderer.window_state)

	renderer.viewport = box_make()
	renderer.viewport.id = -1

	renderer.widget_id = 0
	renderer.dirty = true
	renderer.window_state.renderer = renderer
	renderer.window_state.exit = false
}

renderer_loop :: proc(renderer: ^Renderer) {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	egl.SwapBuffers(renderer.window_state.egl.display, renderer.window_state.egl.surface)

	for wl.display_dispatch(renderer.window_state.wl.display) != -1 && !renderer.window_state.exit {}

	renderer_destroy(renderer)
}

renderer_render :: proc(renderer: ^Renderer) {
	gl.ClearColor(0, 0, 0, 0)
	gl.ClearStencil(0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	if renderer.dirty {
		layout_compute(&renderer.viewport.layout, window_size.x)
		layout_arrange(&renderer.viewport.layout)

		renderer.dirty = false
	}

	renderer_handle_click(renderer)

	box_draw(renderer, renderer.viewport)

	egl.SwapBuffers(renderer.window_state.egl.display, renderer.window_state.egl.surface)
}

renderer_destroy :: proc(renderer: ^Renderer) {
	for _, widget_ in renderer.widgets {
		widget := widget_storage_get_widget(widget_)

		delete(widget.layout.children)
		delete(widget.children)
		widget_free(widget_)
	}
	delete(renderer.window_state.wl.keyboard_state.chars)
	delete(renderer.widgets)
	delete(renderer.viewport.children)
	delete(renderer.viewport.layout.children)
	widget_free(renderer.viewport)
}

renderer_handle_click :: proc(renderer: ^Renderer) {
	clicked := Pointer_Buttons{.Left} <= renderer.window_state.wl.pointer_state.clicked
	if !clicked {
		return
	}

	renderer.window_state.wl.pointer_state.clicked -= Pointer_Buttons{.Left}

	position := renderer.window_state.wl.pointer_state.position

	for _, widget_ in renderer.widgets {
		widget := widget_storage_get_widget(widget_)
		if widget_contains_point(widget, position) && widget.onclick != nil {
			widget.onclick(widget, position)
		}
	}
}

renderer_register_click :: proc(renderer: ^Renderer, widget: WidgetId, onclick: On_Click) -> bool {
	widget_ := renderer_unsafe_get_widget(renderer, widget) or_return
	widget := widget_storage_get_widget(widget_)
	widget.onclick = onclick

	return true
}

renderer_draw_widget :: proc(renderer: ^Renderer, widget: WidgetId, depth: i32) -> bool {
	widget := renderer_unsafe_get_widget(renderer, widget) or_return

	switch widget in widget {
	case ^Box:
		box_draw(renderer, widget, depth)
	case ^Text:
		text_draw(widget, depth)
	}

	return true
}

renderer_register_widget :: proc(
	renderer: ^Renderer,
	widget: $T,
	viewport_child := true,
) -> WidgetId where intrinsics.type_is_variant_of(Widget_Storage, T) ||
	T == Widget_Storage {

	id := WidgetId(renderer.widget_id)
	renderer.widget_id += 1

	renderer.widgets[id] = widget

	widget.id = id

	if viewport_child {
		append(&renderer.viewport.children, id)
		append(&renderer.viewport.layout.children, &widget.layout)
		widget.parent = renderer.viewport.id
	}

	return id
}

renderer_register_child :: proc(
	renderer: ^Renderer,
	parent_id: WidgetId,
	child: $T,
) -> (
	child_id: WidgetId,
	ok: bool,
) where intrinsics.type_is_variant_of(Widget_Storage, T) ||
	T == Widget_Storage {
	child_id = renderer_register_widget(renderer, child, false)

	child := renderer_unsafe_get_widget(renderer, child_id) or_return
	parent := renderer_unsafe_get_widget(renderer, parent_id) or_return

	widget_add_child(widget_storage_get_widget(parent), widget_storage_get_widget(child))

	return
}

@(private)
renderer_unsafe_get_widget :: proc(renderer: ^Renderer, id: WidgetId) -> (Widget_Storage, bool) {
	return renderer.widgets[id]
}

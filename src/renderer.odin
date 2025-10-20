package main

import wl "../lib/wayland"
import "base:runtime"
import "css"

Renderer :: struct {
	ctx:            runtime.Context,
	widgets:        [dynamic]^Widget,
	css:            css.Ast,
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

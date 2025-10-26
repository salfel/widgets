package main

import wl "../lib/wayland"
import "../lib/wayland/xdg"
import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"

Wayland_State :: struct {
	display:        ^wl.display,
	compositor:     ^wl.compositor,
	registry:       ^wl.registry,
	seat:           ^wl.seat,
	surface:        ^wl.surface,
	xdg:            struct {
		wm_base:  ^xdg.wm_base,
		surface:  ^xdg.surface,
		toplevel: ^xdg.toplevel,
	},
	pointer_state:  Pointer_State,
	keyboard_state: Keyboard_State,
}

registry_handle_global :: proc "c" (
	data: rawptr,
	registry: ^wl.registry,
	name: uint,
	interface: cstring,
	version: uint,
) {
	switch interface {
	case wl.compositor_interface.name:
		g_Renderer.wl_state.compositor = cast(^wl.compositor)wl.registry_bind(
			registry,
			name,
			&wl.compositor_interface,
			4,
		)

	case wl.seat_interface.name:
		g_Renderer.wl_state.seat = cast(^wl.seat)wl.registry_bind(registry, name, &wl.seat_interface, 1)
		keyboard := wl.seat_get_keyboard(g_Renderer.wl_state.seat)
		pointer := wl.seat_get_pointer(g_Renderer.wl_state.seat)
		wl.keyboard_add_listener(keyboard, &wl_keyboard_listener, &g_Renderer.wl_state.keyboard_state)
		wl.pointer_add_listener(pointer, &wl_pointer_listener, &g_Renderer.wl_state.pointer_state)
	case xdg.wm_base_interface.name:
		g_Renderer.wl_state.xdg.wm_base = cast(^xdg.wm_base)wl.registry_bind(registry, name, &xdg.wm_base_interface, 1)
		xdg.wm_base_add_listener(g_Renderer.wl_state.xdg.wm_base, &xdg_wm_base_listener, nil)
	}
}

registry_handle_global_remove :: proc "c" (data: rawptr, registry: ^wl.registry, name: uint) {}

registry_listener := wl.registry_listener {
	global        = registry_handle_global,
	global_remove = registry_handle_global_remove,
}

xdg_surface_configure :: proc "c" (data: rawptr, surface: ^xdg.surface, serial: uint) {
	xdg.surface_ack_configure(surface, serial)

	wl.surface_commit(g_Renderer.wl_state.surface)
}

xdg_surface_listener := xdg.surface_listener {
	configure = xdg_surface_configure,
}

xdg_toplevel_configure :: proc "c" (data: rawptr, toplevel: ^xdg.toplevel, width, height: int, states: wl.array) {
	g_Renderer.window_size = [2]f32{f32(width), f32(height)}

	wl.egl_window_resize(g_Renderer.egl_state.window, width, height, 0, 0)
	gl.Viewport(0, 0, i32(width), i32(height))
}

xdg_toplevel_close :: proc "c" (data: rawptr, toplevel: ^xdg.toplevel) {
	g_Renderer.exit = true
}

xdg_toplevel_listener := xdg.toplevel_listener {
	configure = xdg_toplevel_configure,
	close     = xdg_toplevel_close,
}

xdg_wm_base_ping :: proc "c" (data: rawptr, xdg_wm_base: ^xdg.wm_base, serial: uint) {
	xdg.wm_base_pong(xdg_wm_base, serial)
}

xdg_wm_base_listener := xdg.wm_base_listener {
	ping = xdg_wm_base_ping,
}

wl_callback_done :: proc "c" (data: rawptr, callback: ^wl.callback, time: uint) {
	context = g_Renderer.ctx

	wl.callback_destroy(callback)

	callback := wl.surface_frame(g_Renderer.wl_state.surface)
	wl.callback_add_listener(callback, &wl_callback_listener, nil)

	renderer_render()

	wl.surface_commit(g_Renderer.wl_state.surface)
}

wl_callback_listener := wl.callback_listener {
	done = wl_callback_done,
}

wayland_init :: proc() {
	g_Renderer.wl_state.pointer_state = pointer_state_make()
	g_Renderer.wl_state.keyboard_state = keyboard_state_make()

	g_Renderer.wl_state.display = wl.display_connect(nil)

	if g_Renderer.wl_state.display == nil {
		fmt.eprintln("Failed to connect to a wayland display")
		return
	}

	g_Renderer.wl_state.registry = wl.display_get_registry(g_Renderer.wl_state.display)
	wl.registry_add_listener(g_Renderer.wl_state.registry, &registry_listener, nil)
	wl.display_roundtrip(g_Renderer.wl_state.display)

	g_Renderer.wl_state.surface = wl.compositor_create_surface(g_Renderer.wl_state.compositor)

	g_Renderer.wl_state.xdg.surface = xdg.wm_base_get_xdg_surface(
		g_Renderer.wl_state.xdg.wm_base,
		g_Renderer.wl_state.surface,
	)
	xdg.surface_add_listener(g_Renderer.wl_state.xdg.surface, &xdg_surface_listener, nil)

	g_Renderer.wl_state.xdg.toplevel = xdg.surface_get_toplevel(g_Renderer.wl_state.xdg.surface)

	xdg.toplevel_set_title(g_Renderer.wl_state.xdg.toplevel, "widgets")
	xdg.toplevel_set_app_id(g_Renderer.wl_state.xdg.toplevel, "widgets")
	xdg.toplevel_add_listener(g_Renderer.wl_state.xdg.toplevel, &xdg_toplevel_listener, nil)

	wl.surface_commit(g_Renderer.wl_state.surface)

	callback := wl.surface_frame(g_Renderer.wl_state.surface)
	wl.callback_add_listener(callback, &wl_callback_listener, nil)
}

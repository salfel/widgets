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
	callback:       ^wl.callback,
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
	wl_state := cast(^Wayland_State)data

	switch interface {
	case wl.compositor_interface.name:
		wl_state.compositor = cast(^wl.compositor)wl.registry_bind(registry, name, &wl.compositor_interface, 4)

	case wl.seat_interface.name:
		wl_state.seat = cast(^wl.seat)wl.registry_bind(registry, name, &wl.seat_interface, 1)
		keyboard := wl.seat_get_keyboard(wl_state.seat)
		pointer := wl.seat_get_pointer(wl_state.seat)
		wl.keyboard_add_listener(keyboard, &wl_keyboard_listener, &wl_state.keyboard_state)
		wl.pointer_add_listener(pointer, &wl_pointer_listener, &wl_state.pointer_state)
	case xdg.wm_base_interface.name:
		wl_state.xdg.wm_base = cast(^xdg.wm_base)wl.registry_bind(registry, name, &xdg.wm_base_interface, 1)
		xdg.wm_base_add_listener(wl_state.xdg.wm_base, &xdg_wm_base_listener, nil)
	}
}

registry_handle_global_remove :: proc "c" (data: rawptr, registry: ^wl.registry, name: uint) {}

registry_listener := wl.registry_listener {
	global        = registry_handle_global,
	global_remove = registry_handle_global_remove,
}

xdg_surface_configure :: proc "c" (data: rawptr, surface: ^xdg.surface, serial: uint) {
	wl_state := cast(^Wayland_State)data

	xdg.surface_ack_configure(surface, serial)

	wl.surface_commit(wl_state.surface)
}

xdg_surface_listener := xdg.surface_listener {
	configure = xdg_surface_configure,
}

xdg_toplevel_configure :: proc "c" (data: rawptr, toplevel: ^xdg.toplevel, width, height: int, states: wl.array) {
	window_state := cast(^Window_State)data

	window_size = {f32(width), f32(height)}

	wl.egl_window_resize(window_state.egl.window, width, height, 0, 0)
	gl.Viewport(0, 0, i32(width), i32(height))
}

xdg_toplevel_close :: proc "c" (data: rawptr, toplevel: ^xdg.toplevel) {
	window_state := cast(^Window_State)data

	window_state.exit = true
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
	context = global_ctx
	window_state := cast(^Window_State)data

	wl.callback_destroy(callback)
	window_state.wl.callback = nil

	renderer_render(window_state.renderer)

	wl.surface_commit(window_state.wl.surface)
}

wl_callback_listener := wl.callback_listener {
	done = wl_callback_done,
}

register_callback :: proc "contextless" (window_state: ^Window_State) {
	if window_state.wl.callback != nil do return

	window_state.wl.callback = wl.surface_frame(window_state.wl.surface)
	wl.callback_add_listener(window_state.wl.callback, &wl_callback_listener, window_state)

	wl.surface_commit(window_state.wl.surface)
}

wl_init :: proc(window_state: ^Window_State, title, app_id: cstring) {
	window_state.wl.pointer_state = pointer_state_make(window_state)
	window_state.wl.keyboard_state = keyboard_state_make(window_state)

	window_state.wl.display = wl.display_connect(nil)

	if window_state.wl.display == nil {
		fmt.eprintln("Failed to connect to a wayland display")
		return
	}

	window_state.wl.registry = wl.display_get_registry(window_state.wl.display)
	wl.registry_add_listener(window_state.wl.registry, &registry_listener, &window_state.wl)
	wl.display_roundtrip(window_state.wl.display)

	window_state.wl.surface = wl.compositor_create_surface(window_state.wl.compositor)

	window_state.wl.xdg.surface = xdg.wm_base_get_xdg_surface(window_state.wl.xdg.wm_base, window_state.wl.surface)
	xdg.surface_add_listener(window_state.wl.xdg.surface, &xdg_surface_listener, &window_state.wl)

	window_state.wl.xdg.toplevel = xdg.surface_get_toplevel(window_state.wl.xdg.surface)

	xdg.toplevel_set_title(window_state.wl.xdg.toplevel, title)
	xdg.toplevel_set_app_id(window_state.wl.xdg.toplevel, app_id)
	xdg.toplevel_add_listener(window_state.wl.xdg.toplevel, &xdg_toplevel_listener, window_state)

	wl.surface_commit(window_state.wl.surface)

	window_state.wl.callback = wl.surface_frame(window_state.wl.surface)
	wl.callback_add_listener(window_state.wl.callback, &wl_callback_listener, window_state)
}

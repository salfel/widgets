package main

import "core:fmt"
import "core:math"
import "core:slice"
import wl "lib:wayland"
import "lib:wayland/xdg"
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
	context = global_ctx
	app_context := cast(^App_Context)data
	wl_state := &app_context.window.wl

	switch interface {
	case wl.compositor_interface.name:
		wl_state.compositor = cast(^wl.compositor)wl.registry_bind(registry, name, &wl.compositor_interface, 4)
	case wl.seat_interface.name:
		wl_state.seat = cast(^wl.seat)wl.registry_bind(registry, name, &wl.seat_interface, 1)
		// keyboard := wl.seat_get_keyboard(wl_state.seat)
		pointer := wl.seat_get_pointer(wl_state.seat)
		// wl.keyboard_add_listener(keyboard, &wl_keyboard_listener, app_context)
		wl.pointer_add_listener(pointer, &wl_pointer_listener, app_context)
	case xdg.wm_base_interface.name:
		wl_state.xdg.wm_base = cast(^xdg.wm_base)wl.registry_bind(registry, name, &xdg.wm_base_interface, 7)
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
	context = global_ctx
	app_context := cast(^App_Context)data

	size := [2]f32{f32(width), f32(height)}

	if size == app_context.window.size do return

	event_register(Event{type = .Window_Resize, data = size}, app_context)
}

xdg_toplevel_configure_bounds :: proc "c" (data: rawptr, toplevel: ^xdg.toplevel, width, height: int) {}

xdg_toplevel_wm_capabilities :: proc "c" (data: rawptr, toplevel: ^xdg.toplevel, capabilities: wl.array) {}

xdg_toplevel_close :: proc "c" (data: rawptr, toplevel: ^xdg.toplevel) {
	context = global_ctx
	app_context := cast(^App_Context)data

	event_register(Event{type = .Window_Close}, app_context)
}

xdg_toplevel_listener := xdg.toplevel_listener {
	configure        = xdg_toplevel_configure,
	configure_bounds = xdg_toplevel_configure_bounds,
	close            = xdg_toplevel_close,
	wm_capabilities  = xdg_toplevel_wm_capabilities,
}

xdg_wm_base_ping :: proc "c" (data: rawptr, xdg_wm_base: ^xdg.wm_base, serial: uint) {
	xdg.wm_base_pong(xdg_wm_base, serial)
}

xdg_wm_base_listener := xdg.wm_base_listener {
	ping = xdg_wm_base_ping,
}

wl_callback_done :: proc "c" (data: rawptr, callback: ^wl.callback, time: uint) {
	context = global_ctx
	app_context := cast(^App_Context)data

	wl.callback_destroy(callback)
	app_context.window.wl.callback = nil

	renderer_render(app_context)

	wl.surface_commit(app_context.window.wl.surface)
}

wl_callback_listener := wl.callback_listener {
	done = wl_callback_done,
}

wl_register_callback :: proc "contextless" (window_context: ^Window_Context) {
	if window_context.wl.callback != nil do return

	window_context.wl.callback = wl.surface_frame(window_context.wl.surface)
	wl.callback_add_listener(window_context.wl.callback, &wl_callback_listener, window_context)

	wl.surface_commit(window_context.wl.surface)
}

wl_init :: proc(app_context: ^App_Context, title, app_id: cstring) {
	wl_state := &app_context.window.wl

	app_context.window.wl.pointer_state = pointer_state_make()
	app_context.window.wl.keyboard_state = keyboard_state_make()

	wl_state.display = wl.display_connect(nil)

	if wl_state.display == nil {
		fmt.eprintln("Failed to connect to a wayland display")
		return
	}

	wl_state.registry = wl.display_get_registry(wl_state.display)
	wl.registry_add_listener(wl_state.registry, &registry_listener, app_context)
	wl.display_roundtrip(wl_state.display)

	wl_state.surface = wl.compositor_create_surface(wl_state.compositor)

	wl_state.xdg.surface = xdg.wm_base_get_xdg_surface(wl_state.xdg.wm_base, wl_state.surface)
	xdg.surface_add_listener(wl_state.xdg.surface, &xdg_surface_listener, &app_context.window.wl)

	wl_state.xdg.toplevel = xdg.surface_get_toplevel(wl_state.xdg.surface)

	xdg.toplevel_set_title(wl_state.xdg.toplevel, title)
	xdg.toplevel_set_app_id(wl_state.xdg.toplevel, app_id)
	xdg.toplevel_add_listener(wl_state.xdg.toplevel, &xdg_toplevel_listener, app_context)

	wl.surface_commit(wl_state.surface)

	wl_state.callback = wl.surface_frame(wl_state.surface)
	wl.callback_add_listener(wl_state.callback, &wl_callback_listener, app_context)
}

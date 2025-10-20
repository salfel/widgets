package main

import wl "../lib/wayland"
import "core:fmt"

Wayland_State :: struct {
	display:        ^wl.display,
	compositor:     ^wl.compositor,
	seat:           ^wl.seat,
	surface:        ^wl.surface,
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
	}
}

registry_handle_global_remove :: proc "c" (data: rawptr, registry: ^wl.registry, name: uint) {}

registry_listener := wl.registry_listener {
	global        = registry_handle_global,
	global_remove = registry_handle_global_remove,
}

wayland_init :: proc() {
	g_Renderer.wl_state.pointer_state = pointer_state_make()
	g_Renderer.wl_state.keyboard_state = keyboard_state_make()

	g_Renderer.wl_state.display = wl.display_connect(nil)

	if g_Renderer.wl_state.display == nil {
		fmt.eprintln("Failed to connect to a wayland display")
		return
	}

	wl_registry := wl.display_get_registry(g_Renderer.wl_state.display)
	wl.registry_add_listener(wl_registry, &registry_listener, nil)
	wl.display_roundtrip(g_Renderer.wl_state.display)

	g_Renderer.wl_state.surface = wl.compositor_create_surface(g_Renderer.wl_state.compositor)
}

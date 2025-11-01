package main

import "base:runtime"
import "core:fmt"
import wl "lib:wayland"

Pointer_Button :: enum {
	Left    = 0x110,
	Right   = 0x111,
	Middle  = 0x112,
	Side    = 0x113,
	Extra   = 0x114,
	Forward = 0x115,
	Back    = 0x116,
}
Pointer_Buttons :: bit_set[Pointer_Button]

Pointer_State :: struct {
	position: [2]f32,
	surface:  ^wl.surface,
	buttons:  Pointer_Buttons,
	clicked:  Pointer_Buttons,
	scroll:   [wl.pointer_axis]f32,
}

pointer_state_make :: proc() -> Pointer_State {
	return Pointer_State {
		position = [2]f32{0, 0},
		surface = nil,
		buttons = Pointer_Buttons{},
		scroll = {.vertical_scroll = 0, .horizontal_scroll = 0},
	}
}

pointer_enter :: proc "c" (
	data: rawptr,
	pointer: ^wl.pointer,
	serial: uint,
	surface: ^wl.surface,
	surface_x, surface_y: wl.fixed_t,
) {
	app_context := cast(^App_Context)data
	pointer_state := &app_context.window.wl.pointer_state

	pointer_state.surface = surface
	pointer_state.position = [2]f32{f32(surface_x) / 256.0, f32(surface_y) / 256.0}
}

pointer_leave :: proc "c" (data: rawptr, pointer: ^wl.pointer, serial: uint, surface: ^wl.surface) {
	context = global_ctx
	app_context := cast(^App_Context)data
	pointer_state := &app_context.window.wl.pointer_state

	assert(pointer_state.surface == surface)

	pointer_state.surface = nil
}

pointer_motion :: proc "c" (data: rawptr, pointer: ^wl.pointer, time: uint, surface_x, surface_y: wl.fixed_t) {
	context = global_ctx
	app_context := cast(^App_Context)data

	event_register(
		Event{type = .Pointer_Move, data = [2]f32{f32(surface_x) / 256.0, f32(surface_y) / 256.0}},
		app_context,
	)
}

pointer_button :: proc "c" (
	data: rawptr,
	pointer: ^wl.pointer,
	serial: uint,
	time: uint,
	button: uint,
	state: wl.pointer_button_state,
) {
	context = global_ctx

	app_context := cast(^App_Context)data
	pointer_state := &app_context.window.wl.pointer_state

	for ptr_button in Pointer_Button {
		if button == uint(ptr_button) {
			if state == .pressed {
				pointer_state.buttons += Pointer_Buttons{ptr_button}
			} else {
				pointer_state.buttons -= Pointer_Buttons{ptr_button}
				event_register(Event{type = .Pointer_Button, data = ptr_button}, app_context)
			}
		}
	}
}

pointer_axis :: proc "c" (data: rawptr, pointer: ^wl.pointer, time: uint, axis: wl.pointer_axis, value: wl.fixed_t) {
	app_context := cast(^App_Context)data
	pointer_state := &app_context.window.wl.pointer_state

	pointer_state.scroll[axis] = f32(value)
}

wl_pointer_listener := wl.pointer_listener {
	enter  = pointer_enter,
	leave  = pointer_leave,
	motion = pointer_motion,
	button = pointer_button,
	axis   = pointer_axis,
}

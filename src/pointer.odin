package main

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
	surface: ^wl.surface,
}

pointer_enter :: proc "c" (
	data: rawptr,
	pointer: ^wl.pointer,
	serial: uint,
	surface: ^wl.surface,
	surface_x, surface_y: wl.fixed_t,
) {
	app_context := cast(^App_Context)data
	context = app_context.ctx
	pointer_state := &app_context.window.wl.pointer_state

	pointer_state.surface = surface
	event_register(
		Event{type = .Pointer_Move, data = [2]f32{f32(surface_x) / 256.0, f32(surface_y) / 256.0}},
		app_context,
	)
}

pointer_leave :: proc "c" (data: rawptr, pointer: ^wl.pointer, serial: uint, surface: ^wl.surface) {
	app_context := cast(^App_Context)data
	context = app_context.ctx
	pointer_state := &app_context.window.wl.pointer_state

	assert(pointer_state.surface == surface)

	pointer_state.surface = nil
}

pointer_motion :: proc "c" (data: rawptr, pointer: ^wl.pointer, time: uint, surface_x, surface_y: wl.fixed_t) {
	app_context := cast(^App_Context)data
	context = app_context.ctx

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
	app_context := cast(^App_Context)data
	context = app_context.ctx
	pointer_state := &app_context.window.wl.pointer_state

	for ptr_button in Pointer_Button {
		if button == uint(ptr_button) {
			if state == .pressed {
				event_register(Event{type = .Pointer_Press, data = ptr_button}, app_context)
			} else {
				event_register(Event{type = .Pointer_Release, data = ptr_button}, app_context)
			}
		}
	}
}

pointer_axis :: proc "c" (data: rawptr, pointer: ^wl.pointer, time: uint, axis: wl.pointer_axis, value: wl.fixed_t) {}
pointer_frame :: proc "c" (data: rawptr, pointer: ^wl.pointer) {}
pointer_axis_source :: proc "c" (data: rawptr, pointer: ^wl.pointer, axis_source: wl.pointer_axis_source) {}
pointer_axis_stop :: proc "c" (data: rawptr, pointer: ^wl.pointer, time: uint, axis: wl.pointer_axis) {}
pointer_axis_discrete :: proc "c" (data: rawptr, pointer: ^wl.pointer, axis: wl.pointer_axis, discrete: int) {}
pointer_axis_value120 :: proc "c" (data: rawptr, pointer: ^wl.pointer, axis: wl.pointer_axis, value120: int) {}
pointer_axis_relative_direction :: proc "c" (
	data: rawptr,
	pointer: ^wl.pointer,
	axis: wl.pointer_axis,
	direction: wl.pointer_axis_relative_direction,
) {}

wl_pointer_listener := wl.pointer_listener {
	enter                   = pointer_enter,
	leave                   = pointer_leave,
	motion                  = pointer_motion,
	button                  = pointer_button,
	axis                    = pointer_axis,
	frame                   = pointer_frame,
	axis_source             = pointer_axis_source,
	axis_stop               = pointer_axis_stop,
	axis_discrete           = pointer_axis_discrete,
	axis_value120           = pointer_axis_value120,
	axis_relative_direction = pointer_axis_relative_direction,
}

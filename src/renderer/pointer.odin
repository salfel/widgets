package renderer

import wl "../../lib/wayland"
import "../state"
import "base:runtime"
import "core:fmt"

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
	pointer_state := cast(^Pointer_State)data

	pointer_state.surface = surface
	pointer_state.position = [2]f32{f32(surface_x) / 256.0, f32(surface_y) / 256.0}
}

pointer_leave :: proc "c" (data: rawptr, pointer: ^wl.pointer, serial: uint, surface: ^wl.surface) {
	pointer_state := cast(^Pointer_State)data
	context = state.app_state.ctx

	assert(pointer_state.surface == surface)

	pointer_state.surface = nil
}

pointer_motion :: proc "c" (data: rawptr, pointer: ^wl.pointer, time: uint, surface_x, surface_y: wl.fixed_t) {
	pointer_state := cast(^Pointer_State)data

	pointer_state.position = [2]f32{f32(surface_x) / 256.0, f32(surface_y) / 256.0}
}

pointer_button :: proc "c" (
	data: rawptr,
	pointer: ^wl.pointer,
	serial: uint,
	time: uint,
	button: uint,
	state: wl.pointer_button_state,
) {
	pointer_state := cast(^Pointer_State)data

	if state == .pressed {
		switch button {
		case uint(Pointer_Button.Left):
			pointer_state.buttons += Pointer_Buttons{Pointer_Button.Left}
		case uint(Pointer_Button.Right):
			pointer_state.buttons += Pointer_Buttons{Pointer_Button.Right}
		case uint(Pointer_Button.Middle):
			pointer_state.buttons += Pointer_Buttons{Pointer_Button.Middle}
		case uint(Pointer_Button.Side):
			pointer_state.buttons += Pointer_Buttons{Pointer_Button.Side}
		case uint(Pointer_Button.Extra):
			pointer_state.buttons += Pointer_Buttons{Pointer_Button.Extra}
		case uint(Pointer_Button.Forward):
			pointer_state.buttons += Pointer_Buttons{Pointer_Button.Forward}
		case uint(Pointer_Button.Back):
			pointer_state.buttons += Pointer_Buttons{Pointer_Button.Back}
		}
	} else {
		switch button {
		case uint(Pointer_Button.Left):
			pointer_state.buttons -= Pointer_Buttons{Pointer_Button.Left}
		case uint(Pointer_Button.Right):
			pointer_state.buttons -= Pointer_Buttons{Pointer_Button.Right}
		case uint(Pointer_Button.Middle):
			pointer_state.buttons -= Pointer_Buttons{Pointer_Button.Middle}
		case uint(Pointer_Button.Side):
			pointer_state.buttons -= Pointer_Buttons{Pointer_Button.Side}
		case uint(Pointer_Button.Extra):
			pointer_state.buttons -= Pointer_Buttons{Pointer_Button.Extra}
		case uint(Pointer_Button.Forward):
			pointer_state.buttons -= Pointer_Buttons{Pointer_Button.Forward}
		case uint(Pointer_Button.Back):
			pointer_state.buttons -= Pointer_Buttons{Pointer_Button.Back}
		}
	}
}

pointer_axis :: proc "c" (data: rawptr, pointer: ^wl.pointer, time: uint, axis: wl.pointer_axis, value: wl.fixed_t) {
	pointer_state := cast(^Pointer_State)data

	pointer_state.scroll[axis] = f32(value)
}

wl_pointer_listener := wl.pointer_listener {
	enter  = pointer_enter,
	leave  = pointer_leave,
	motion = pointer_motion,
	button = pointer_button,
	axis   = pointer_axis,
}

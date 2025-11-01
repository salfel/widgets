package main

import "base:runtime"
import "core:fmt"
import vmem "core:mem/virtual"
import "core:os"
import "core:strings"
import wl "lib:wayland"
import xkb "lib:xkbcommon"


Modifier :: enum {
	Shift,
	Caps,
	Ctrl,
	Alt,
}
Modifiers :: bit_set[Modifier]

Keyboard_State :: struct {
	xkb:         struct {
		ctx:    ^xkb.ctx,
		keymap: ^xkb.keymap,
		state:  ^xkb.state,
	},
	modifiers:   Modifiers,
	mod_indices: [Modifier]u32,
	chars:       [dynamic]rune,
}

keyboard_state_make :: proc(allocator := context.allocator) -> Keyboard_State {
	return Keyboard_State {
		xkb = {},
		modifiers = Modifiers{},
		mod_indices = [Modifier]u32{},
		chars = make([dynamic]rune, allocator),
	}
}

handle_keymap :: proc "c" (
	data: rawptr,
	keyboard: ^wl.keyboard,
	format: wl.keyboard_keymap_format,
	fd: int,
	size: uint,
) {
	context = global_ctx
	app_context := cast(^App_Context)data
	keyboard_state := &app_context.window.wl.keyboard_state

	defer os.close(cast(os.Handle)fd)

	map_shm, err := vmem.map_file_from_file_descriptor(uintptr(fd), vmem.Map_File_Flags{.Read})
	if err != .None {
		fmt.eprintln("Failed to map file", err)
		return
	}

	keymap_string := strings.clone_to_cstring(string(map_shm))
	defer {vmem.release(raw_data(map_shm), uint(len(map_shm)))
		delete(keymap_string)
	}

	keyboard_state.xkb.ctx = xkb.context_new(.No_Flags)
	keyboard_state.xkb.keymap = xkb.keymap_new_from_string(keyboard_state.xkb.ctx, keymap_string, .Text_V1, .No_Flags)
	if keyboard_state.xkb.keymap == nil {
		fmt.eprintln("Failed to compile keymap")
		return
	}

	keyboard_state.xkb.state = xkb.state_new(keyboard_state.xkb.keymap)
}

handle_enter :: proc "c" (data: rawptr, keyboard: ^wl.keyboard, serial: uint, surface: ^wl.surface, keys: wl.array) {}
handle_leave :: proc "c" (data: rawptr, keyboard: ^wl.keyboard, serial: uint, surface: ^wl.surface) {}

handle_key :: proc "c" (data: rawptr, keyboard: ^wl.keyboard, serial, time, key: uint, _state: wl.keyboard_key_state) {
	context = global_ctx
	app_context := cast(^App_Context)data
	keyboard_state := &app_context.window.wl.keyboard_state

	if _state != .PRESSED {
		return
	}

	sym := xkb.state_key_get_one_sym(keyboard_state.xkb.state, i32(key + 8))

	utf8 := make([]u8, 8)
	defer delete(utf8)
	utf8_len := xkb.keysym_to_utf8(sym, cast(^i8)&utf8[0], i32(len(utf8)))

	if utf8_len == 0 do return

	reader: strings.Reader
	char := cstring(raw_data(utf8))
	strings.reader_init(&reader, string(char))
	r, size, err := strings.reader_read_rune(&reader)

	if err != .None {
		fmt.eprintln("Failed to read rune", err)
		return
	}

	append(&keyboard_state.chars, r)

	wl_register_callback(&app_context.window)
}

handle_modifiers :: proc "c" (
	data: rawptr,
	keyboard: ^wl.keyboard,
	serial: uint,
	mods_depressed: uint,
	mods_latched: uint,
	mods_locked: uint,
	group: uint,
) {
	context = global_ctx
	app_context := cast(^App_Context)data
	keyboard_state := &app_context.window.wl.keyboard_state

	xkb.state_update_mask(
		keyboard_state.xkb.state,
		i32(mods_depressed),
		i32(mods_latched),
		i32(mods_locked),
		0,
		0,
		i32(group),
	)

	keyboard_state.mod_indices[.Shift] = u32(xkb.keymap_mod_get_index(keyboard_state.xkb.keymap, xkb.MOD_NAME_SHIFT))
	keyboard_state.mod_indices[.Caps] = u32(xkb.keymap_mod_get_index(keyboard_state.xkb.keymap, xkb.MOD_NAME_CAPS))
	keyboard_state.mod_indices[.Ctrl] = u32(xkb.keymap_mod_get_index(keyboard_state.xkb.keymap, xkb.MOD_NAME_CTRL))
	keyboard_state.mod_indices[.Alt] = u32(xkb.keymap_mod_get_index(keyboard_state.xkb.keymap, xkb.MOD_NAME_ALT))

	mods := xkb.state_serialize_mods(keyboard_state.xkb.state, .Mods_Effective)

	for mod in Modifier {
		if mods & (1 << keyboard_state.mod_indices[mod]) != 0 {
			keyboard_state.modifiers += Modifiers{mod}
		} else if mod in keyboard_state.modifiers {
			keyboard_state.modifiers -= Modifiers{mod}
		}
	}

	wl_register_callback(&app_context.window)
}

handle_repeat_info :: proc "c" (data: rawptr, keyboard: ^wl.keyboard, rate: int, delay: int) {}

wl_keyboard_listener := wl.keyboard_listener {
	keymap      = handle_keymap,
	enter       = handle_enter,
	leave       = handle_leave,
	key         = handle_key,
	modifiers   = handle_modifiers,
	repeat_info = handle_repeat_info,
}

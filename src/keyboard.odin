package main

import "base:runtime"
import "core:fmt"
import vmem "core:mem/virtual"
import "core:os"
import "core:strings"
import "core:time"
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
	mod_indices:  [Modifier]u32,
	pressed_keys: map[i32]^Repeat_Data,
	repeat:       struct {
		delay, interval: time.Duration,
	},
	xkb:          struct {
		ctx:    ^xkb.ctx,
		keymap: ^xkb.keymap,
		state:  ^xkb.state,
	},
}

Repeat_Data :: struct {
	app_context: ^App_Context,
	key:         Key,
	timer_id:    Timer_Id,
}

keyboard_state_init :: proc(keyboard_state: ^Keyboard_State, allocator := context.allocator) {
	keyboard_state.pressed_keys = make(map[i32]^Repeat_Data, allocator)
}

keyboard_state_destroy :: proc(keyboard_state: ^Keyboard_State) {
	for _, repeat_data in keyboard_state.pressed_keys {
		timer_stop(&repeat_data.app_context.timer, repeat_data.timer_id)
		free(repeat_data)
	}
	delete(keyboard_state.pressed_keys)
}

handle_keymap :: proc "c" (
	data: rawptr,
	keyboard: ^wl.keyboard,
	format: wl.keyboard_keymap_format,
	fd: int,
	size: uint,
) {
	app_context := cast(^App_Context)data
	context = app_context.ctx
	keyboard_state := &app_context.window.wl.keyboard_state

	defer os.close(cast(os.Handle)fd)

	map_shm, err := vmem.map_file_from_file_descriptor(uintptr(fd), vmem.Map_File_Flags{.Read})
	if err != .None {
		fmt.eprintln("Failed to map file", err)
		return
	}

	keymap_string := strings.clone_to_cstring(string(map_shm))
	defer {
		vmem.release(raw_data(map_shm), uint(len(map_shm)))
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
handle_leave :: proc "c" (data: rawptr, keyboard: ^wl.keyboard, serial: uint, surface: ^wl.surface) {
	app_context := cast(^App_Context)data
	keyboard_state := &app_context.window.wl.keyboard_state
	context = app_context.ctx

	for _, repeat_data in keyboard_state.pressed_keys {
		timer_stop(&repeat_data.app_context.timer, repeat_data.timer_id)
		free(repeat_data)
	}
}

handle_key :: proc "c" (data: rawptr, keyboard: ^wl.keyboard, serial, _time, key: uint, state: wl.keyboard_key_state) {
	app_context := cast(^App_Context)data
	context = app_context.ctx
	keyboard_state := &app_context.window.wl.keyboard_state

	sym := xkb.state_key_get_one_sym(keyboard_state.xkb.state, i32(key + 8))

	key: Key
	switch sym {
	case xkb.KEY_BackSpace:
		key.type = .Backspace
	case xkb.KEY_Delete:
		key.type = .Delete
	case xkb.KEY_Return:
		key.type = .Enter
	case xkb.KEY_Escape:
		key.type = .Escape
	case xkb.KEY_Left:
		key.type = .Left
	case xkb.KEY_Right:
		key.type = .Right
	case xkb.KEY_Up:
		key.type = .Up
	case xkb.KEY_Down:
		key.type = .Down
	case:
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

		key = Key {
			type = .Char,
			char = r,
		}
	}

	key_repeat_handler :: proc(data: rawptr) {
		repeat_data := cast(^Repeat_Data)data

		event_register(Event{type = .Keyboard_Char, data = repeat_data.key}, repeat_data.app_context)
	}

	if state == .PRESSED {
		repeat_data := new(Repeat_Data)
		repeat_data.app_context = app_context
		repeat_data.key = key
		repeat_data.timer_id = timer_set_interval(
			&app_context.timer,
			key_repeat_handler,
			repeat_data,
			keyboard_state.repeat.interval,
			keyboard_state.repeat.delay,
		)

		keyboard_state.pressed_keys[sym] = repeat_data
		event_register(Event{type = .Keyboard_Char, data = repeat_data.key}, repeat_data.app_context)
	} else if state == .RELEASED {
		repeat_data, ok := keyboard_state.pressed_keys[sym]
		if ok {
			ok := timer_stop(&app_context.timer, repeat_data.timer_id)
			assert(ok)

			free(keyboard_state.pressed_keys[sym])
			delete_key(&keyboard_state.pressed_keys, sym)
		}
	}
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
	app_context := cast(^App_Context)data
	context = app_context.ctx
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
			event_register(Event{type = .Keyboard_Modifier_Activated, data = mod}, app_context)
		} else {
			event_register(Event{type = .Keyboard_Modifier_Deactivated, data = mod}, app_context)
		}
	}
}

handle_repeat_info :: proc "c" (data: rawptr, keyboard: ^wl.keyboard, rate: int, delay: int) {
	app_context := cast(^App_Context)data
	keyboard_state := &app_context.window.wl.keyboard_state

	keyboard_state.repeat.delay = time.Duration(delay) * time.Millisecond
	keyboard_state.repeat.interval = time.Second / time.Duration(rate)
}

wl_keyboard_listener := wl.keyboard_listener {
	keymap      = handle_keymap,
	enter       = handle_enter,
	leave       = handle_leave,
	key         = handle_key,
	modifiers   = handle_modifiers,
	repeat_info = handle_repeat_info,
}

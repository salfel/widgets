package main

import wl "../lib/wayland"
import "../lib/wayland/ext/libdecor"
import xkb "../lib/xkbcommon"
import "base:runtime"
import "core:fmt"
import vmem "core:mem/virtual"
import "core:os"
import "core:strings"
import gl "vendor:OpenGL"
import "vendor:egl"
import "vendor:glfw"
import "vendor:x11/xlib"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

window: struct {
	wl:       struct {
		display:    ^wl.display,
		compositor: ^wl.compositor,
		surface:    ^wl.surface,
		shm:        ^wl.shm,
		seat:       ^wl.seat,
		egl_window: ^wl.egl_window,
	},
	egl:      struct {
		display: egl.Display,
		surface: egl.Surface,
		ctx:     egl.Context,
	},
	libdecor: struct {
		instance: ^libdecor.instance,
		frame:    ^libdecor.frame,
	},
	input:    struct {
		ctx:    ^xkb.ctx,
		keymap: ^xkb.keymap,
		state:  ^xkb.state,
	},
	size:     [2]int,
	ctx:      runtime.Context,
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
		window.wl.compositor = cast(^wl.compositor)wl.registry_bind(registry, name, &wl.compositor_interface, 4)
	case wl.seat_interface.name:
		window.wl.seat = cast(^wl.seat)wl.registry_bind(registry, name, &wl.seat_interface, 1)
		keyboard := wl.seat_get_keyboard(window.wl.seat)
		pointer := wl.seat_get_pointer(window.wl.seat)
		wl.keyboard_add_listener(keyboard, &wl_keyboard_listener, nil)
		wl.pointer_add_listener(pointer, &wl_pointer_listener, nil)
	}
}

registry_handle_global_remove :: proc "c" (data: rawptr, registry: ^wl.registry, name: uint) {}

registry_listener := wl.registry_listener {
	global        = registry_handle_global,
	global_remove = registry_handle_global_remove,
}

frame_close :: proc "c" (frame: ^libdecor.frame, user_data: rawptr) {
	os.exit(0)
}

frame_commit :: proc "c" (frame: ^libdecor.frame, user_data: rawptr) {
	egl.SwapBuffers(window.egl.display, window.egl.surface)
}

frame_configure :: proc "c" (frame: ^libdecor.frame, configuration: ^libdecor.configuration, user_data: rawptr) {
	width, height: int

	if !libdecor.configuration_get_content_size(configuration, frame, &width, &height) {
		width = 1280
		height = 720
	}

	wl.egl_window_resize(window.wl.egl_window, width, height, 0, 0)
	gl.Viewport(0, 0, cast(i32)width, cast(i32)height)

	libdecor_state := libdecor.state_new(width, height)
	libdecor.frame_commit(frame, libdecor_state, configuration)
	libdecor.state_free(libdecor_state)

	window.size = {width, height}
	app_state.window_size = [2]f32{f32(width), f32(height)}
}

frame_interface := libdecor.frame_interface {
	close     = frame_close,
	commit    = frame_commit,
	configure = frame_configure,
}

interface_error :: proc "c" (instance: ^libdecor.instance, error: libdecor.error, message: cstring) {
	context = window.ctx

	fmt.println("libdecor error", error, message)

	os.exit(1)
}

interface := libdecor.interface {
	error = interface_error,
}

init_wayland :: proc() {
	window.wl.display = wl.display_connect(nil)

	if window.wl.display == nil {
		fmt.eprintln("Failed to connect to a wayland display")
		return
	}

	wl_registry := wl.display_get_registry(window.wl.display)
	wl.registry_add_listener(wl_registry, &registry_listener, nil)
	wl.display_roundtrip(window.wl.display)

	window.wl.surface = wl.compositor_create_surface(window.wl.compositor)
}

init_egl :: proc() {
	major, minor: i32
	egl.BindAPI(egl.OPENGL_API)
	config_attribs := []i32 {
		egl.SURFACE_TYPE,
		egl.WINDOW_BIT,
		egl.RENDERABLE_TYPE,
		egl.OPENGL_BIT,
		egl.RED_SIZE,
		8,
		egl.GREEN_SIZE,
		8,
		egl.BLUE_SIZE,
		8,
		egl.DEPTH_SIZE,
		24,
		egl.STENCIL_SIZE,
		8,
		egl.NONE,
	}

	window.egl.display = egl.GetDisplay(cast(egl.NativeDisplayType)window.wl.display)
	if window.egl.display == nil {
		fmt.println("Failed to get EGL display")
		return
	}

	egl.Initialize(window.egl.display, &major, &minor)
	fmt.println("EGL Major, EGL Minor", major, minor)

	config: egl.Config
	num_config: i32

	egl.ChooseConfig(window.egl.display, raw_data(config_attribs), &config, 1, &num_config)
	window.egl.ctx = egl.CreateContext(window.egl.display, config, nil, nil)
	window.wl.egl_window = wl.egl_window_create(window.wl.surface, 1280, 720)
	window.egl.surface = egl.CreateWindowSurface(
		window.egl.display,
		config,
		cast(egl.NativeWindowType)window.wl.egl_window,
		nil,
	)
	wl.surface_commit(window.wl.surface)
	egl.MakeCurrent(window.egl.display, window.egl.surface, window.egl.surface, window.egl.ctx)
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, egl.gl_set_proc_address)

	egl.SwapInterval(window.egl.display, 1)
}

init_libdecor :: proc(app_id, title: cstring) {
	window.libdecor.instance = libdecor.new(window.wl.display, &interface)
	window.libdecor.frame = libdecor.decorate(window.libdecor.instance, window.wl.surface, &frame_interface, nil)
	libdecor.frame_set_app_id(window.libdecor.frame, app_id)
	libdecor.frame_set_title(window.libdecor.frame, title)
	libdecor.frame_map(window.libdecor.frame)
	wl.display_dispatch(window.wl.display)
	wl.display_dispatch(window.wl.display)
}

handle_keymap :: proc "c" (
	data: rawptr,
	keyboard: ^wl.keyboard,
	format: wl.keyboard_keymap_format,
	fd: int,
	size: uint,
) {
	context = window.ctx

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

	window.input.ctx = xkb.context_new(.No_Flags)
	window.input.keymap = xkb.keymap_new_from_string(window.input.ctx, keymap_string, .Text_V1, .No_Flags)
	if window.input.keymap == nil {
		fmt.eprintln("Failed to compile keymap")
		return
	}

	window.input.state = xkb.state_new(window.input.keymap)
}

handle_enter :: proc "c" (data: rawptr, keyboard: ^wl.keyboard, serial: uint, surface: ^wl.surface, keys: wl.array) {}
handle_leave :: proc "c" (data: rawptr, keyboard: ^wl.keyboard, serial: uint, surface: ^wl.surface) {}

handle_key :: proc "c" (data: rawptr, keyboard: ^wl.keyboard, serial, time, key: uint, state: wl.keyboard_key_state) {
	context = window.ctx

	if state != .PRESSED {
		return
	}

	sym := xkb.state_key_get_one_sym(window.input.state, i32(key + 8))

	utf8 := make([]u8, 8)
	utf8_len := xkb.keysym_to_utf8(sym, cast(^i8)&utf8[0], i32(len(utf8)))

	if utf8_len == 0 do return

	char := cstring(raw_data(utf8))

	fmt.print(char)
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
	context = window.ctx

	xkb.state_update_mask(
		window.input.state,
		i32(mods_depressed),
		i32(mods_latched),
		i32(mods_locked),
		0,
		0,
		i32(group),
	)

	mod_ctrl := xkb.keymap_mod_get_index(window.input.keymap, xkb.MOD_NAME_CTRL)

	if bool(xkb.state_mod_name_is_active(window.input.state, xkb.MOD_NAME_CTRL, .Mods_Effective)) {
		fmt.print("ctrl")
	}
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

pointer_enter :: proc "c" (
	data: rawptr,
	pointer: ^wl.pointer,
	serial: uint,
	surface: ^wl.surface,
	surface_x, surface_y: wl.fixed_t,
) {
	context = window.ctx

	fmt.println("pointer enter", surface_x / 256.0, surface_y / 256.0)
}

pointer_leave :: proc "c" (data: rawptr, pointer: ^wl.pointer, serial: uint, surface: ^wl.surface) {
	context = window.ctx

	fmt.println("pointer leave")
}

pointer_motion :: proc "c" (data: rawptr, pointer: ^wl.pointer, time: uint, surface_x, surface_y: wl.fixed_t) {
	context = window.ctx

	fmt.println("pointer motion", surface_x / 256.0, surface_y / 256.0)
}

pointer_button :: proc "c" (
	data: rawptr,
	pointer: ^wl.pointer,
	serial: uint,
	time: uint,
	button: uint,
	state: wl.pointer_button_state,
) {
	context = window.ctx

	fmt.println("pointer button", button, state)
}

pointer_axis :: proc "c" (data: rawptr, pointer: ^wl.pointer, time: uint, axis: wl.pointer_axis, value: wl.fixed_t) {}

wl_pointer_listener := wl.pointer_listener {
	enter  = pointer_enter,
	leave  = pointer_leave,
	motion = pointer_motion,
	button = pointer_button,
	axis   = pointer_axis,
}

window_init :: proc(app_id, title: cstring) {
	window.ctx = context

	init_wayland()
	init_egl()
	init_libdecor(app_id, title)
}

window_should_render :: proc() -> bool {
	return wl.display_dispatch_pending(window.wl.display) != -1
}

window_swap :: proc() {
	egl.SwapBuffers(window.egl.display, window.egl.surface)
}

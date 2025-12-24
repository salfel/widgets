package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/linux"
import "core:sys/posix"
import wl "lib:wayland"
import "wl_custom"

// TODO: middle click paste not implemented yet

Clipboard_State :: struct {
	control_manager: ^wl_custom.data_control_manager_v1,
	control_device:  ^wl_custom.data_control_device_v1,
	control_source:  ^wl_custom.data_control_source_v1,
	control_offer:   ^wl_custom.data_control_offer_v1,
	seat:            ^wl.seat,
	data:            Maybe(string),
}

clipboard_init :: proc(clipboard_state: ^Clipboard_State, seat: ^wl.seat, allocator := context.allocator) {
	clipboard_state.seat = seat

	clipboard_state.control_device = wl_custom.data_control_manager_v1_get_data_device(
		clipboard_state.control_manager,
		clipboard_state.seat,
	)

	wl_custom.data_control_device_v1_add_listener(
		clipboard_state.control_device,
		&clipboard_control_device_listener,
		clipboard_state,
	)
}

clipboard_destroy :: proc(clipboard_state: ^Clipboard_State) {
	if text, ok := clipboard_state.data.(string); ok {
		delete(text)
	}
}

// Copy
clipboard_control_source_listener := wl_custom.data_control_source_v1_listener {
	send      = clipboard_control_source_send,
	cancelled = clipboard_control_source_cancelled,
}

clipboard_control_source_send :: proc "c" (
	data: rawptr,
	source: ^wl_custom.data_control_source_v1,
	mime: cstring,
	fd: int,
) {
	app_context := cast(^App_Context)data
	context = app_context.ctx

	text, ok := app_context.window.wl.clipboard_state.data.(string)
	assert(ok, "Expected string to be non-nil")

	switch mime {
	case "text/plain;charset=utf-8", "text/plain":
		new_action, old_action: posix.sigaction_t
		new_action.sa_handler = cast(proc "c" (_: posix.Signal))posix.SIG_IGN
		posix.sigemptyset(&new_action.sa_mask)

		posix.sigaction(.SIGPIPE, &new_action, &old_action)

		os.write(os.Handle(fd), transmute([]u8)text)
		os.close(os.Handle(fd))

		posix.sigaction(.SIGPIPE, &old_action, nil)
	case:
		fmt.eprintln("unsupported mime type", mime)
	}
}

clipboard_control_source_cancelled :: proc "c" (data: rawptr, source: ^wl_custom.data_control_source_v1) {
	clipboard_state := cast(^Clipboard_State)data

	wl_custom.data_control_source_v1_destroy(source)
	clipboard_state.control_source = nil
}

// Paste
clipboard_control_device_listener := wl_custom.data_control_device_v1_listener {
	data_offer        = clipboard_control_device_data_offer,
	finished          = clipboard_control_device_finished,
	selection         = clipboard_control_device_selection,
	primary_selection = clipboard_control_device_primary_selection,
}

clipboard_control_device_data_offer :: proc "c" (
	data: rawptr,
	device: ^wl_custom.data_control_device_v1,
	offer: ^wl_custom.data_control_offer_v1,
) {
	clipboard_state := cast(^Clipboard_State)data
	context = runtime.default_context()

	wl_custom.data_control_offer_v1_add_listener(offer, &clipboard_control_offer_listener, clipboard_state)
}

clipboard_control_device_selection :: proc "c" (
	data: rawptr,
	device: ^wl_custom.data_control_device_v1,
	offer: ^wl_custom.data_control_offer_v1,
) {
	clipboard_state := cast(^Clipboard_State)data
	context = runtime.default_context()

	if clipboard_state.control_offer != nil {
		wl_custom.data_control_offer_v1_destroy(clipboard_state.control_offer)
	}

	clipboard_state.control_offer = offer
}

clipboard_control_device_primary_selection :: proc "c" (
	data: rawptr,
	device: ^wl_custom.data_control_device_v1,
	offer: ^wl_custom.data_control_offer_v1,
) {}

clipboard_control_device_finished :: proc "c" (data: rawptr, device: ^wl_custom.data_control_device_v1) {
	clipboard_state := cast(^Clipboard_State)data

	wl_custom.data_control_device_v1_destroy(device)
	clipboard_state.control_device = nil
}

clipboard_control_offer_listener := wl_custom.data_control_offer_v1_listener {
	offer = clipboard_control_offer_offer,
}

clipboard_control_offer_offer :: proc "c" (data: rawptr, offer: ^wl_custom.data_control_offer_v1, mime_type: cstring) {
	// TODO: set available mime types
}

clipboard_copy :: proc(text: string, app_context: ^App_Context) {
	if text, ok := app_context.window.wl.clipboard_state.data.(string); ok {
		delete(text)
	}
	app_context.window.wl.clipboard_state.data = strings.clone(text)

	app_context.window.wl.clipboard_state.control_source = wl_custom.data_control_manager_v1_create_data_source(
		app_context.window.wl.clipboard_state.control_manager,
	)
	wl_custom.data_control_source_v1_add_listener(
		app_context.window.wl.clipboard_state.control_source,
		&clipboard_control_source_listener,
		app_context,
	)
	wl_custom.data_control_source_v1_offer(
		app_context.window.wl.clipboard_state.control_source,
		"text/plain;charset=utf-8",
	)
	wl_custom.data_control_source_v1_offer(app_context.window.wl.clipboard_state.control_source, "text/plain")

	wl_custom.data_control_device_v1_set_selection(
		app_context.window.wl.clipboard_state.control_device,
		app_context.window.wl.clipboard_state.control_source,
	)
}

clipboard_paste :: proc(app_context: ^App_Context) -> string {
	clipboard_state := &app_context.window.wl.clipboard_state

	fds := [2]linux.Fd{}
	linux.pipe2(&fds, {})
	wl_custom.data_control_offer_v1_receive(clipboard_state.control_offer, "text/plain;charset=utf-8", int(fds[1]))
	linux.close(fds[1])

	wl.display_roundtrip(app_context.window.wl.display)

	builder := strings.builder_make(context.temp_allocator)
	buf := [1024]u8{}
	for {
		size, errno := linux.read(fds[0], buf[:])
		strings.write_bytes(&builder, buf[:size])
		if size <= 0 || size < 1024 {
			break
		}
	}

	return strings.to_string(builder)
}

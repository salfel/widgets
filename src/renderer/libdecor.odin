package renderer

import wl "../../lib/wayland"
import "../../lib/wayland/ext/libdecor"
import "../state"
import "base:runtime"
import "core:fmt"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:egl"

Libdecor_State :: struct {
	instance: ^libdecor.instance,
	frame:    ^libdecor.frame,
}

frame_close :: proc "c" (frame: ^libdecor.frame, user_data: rawptr) {
	os.exit(0)
}

frame_commit :: proc "c" (frame: ^libdecor.frame, user_data: rawptr) {
	egl.SwapBuffers(g_Renderer.egl_state.display, g_Renderer.egl_state.surface)
}

frame_configure :: proc "c" (frame: ^libdecor.frame, configuration: ^libdecor.configuration, user_data: rawptr) {
	width, height: int

	if !libdecor.configuration_get_content_size(configuration, frame, &width, &height) {
		width = 1280
		height = 720
	}

	wl.egl_window_resize(g_Renderer.egl_state.window, width, height, 0, 0)
	gl.Viewport(0, 0, cast(i32)width, cast(i32)height)

	libdecor_state := libdecor.state_new(width, height)
	libdecor.frame_commit(frame, libdecor_state, configuration)
	libdecor.state_free(libdecor_state)

	state.app_state.window_size = [2]f32{f32(width), f32(height)}
}

frame_interface := libdecor.frame_interface {
	close     = frame_close,
	commit    = frame_commit,
	configure = frame_configure,
}

interface_error :: proc "c" (instance: ^libdecor.instance, error: libdecor.error, message: cstring) {
	context = runtime.default_context()

	fmt.eprintln("libdecor error", error, message)

	os.exit(1)
}

interface := libdecor.interface {
	error = interface_error,
}

libdecor_init :: proc(app_id, title: cstring) {
	g_Renderer.libdecor_state.instance = libdecor.new(g_Renderer.wl_state.display, &interface)
	g_Renderer.libdecor_state.frame = libdecor.decorate(
		g_Renderer.libdecor_state.instance,
		g_Renderer.wl_state.surface,
		&frame_interface,
		&g_Renderer.egl_state,
	)
	libdecor.frame_set_app_id(g_Renderer.libdecor_state.frame, app_id)
	libdecor.frame_set_title(g_Renderer.libdecor_state.frame, title)
	libdecor.frame_map(g_Renderer.libdecor_state.frame)
	wl.display_dispatch(g_Renderer.wl_state.display)
	wl.display_dispatch(g_Renderer.wl_state.display)
}

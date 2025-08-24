package widgets

import "../state"
import "base:runtime"
import "core:fmt"
import "core:strings"
import gl "vendor:OpenGL"
import "vendor:glfw"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

window_size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	context = runtime.default_context()

	gl.Viewport(0, 0, width, height)
	state.app_state.window = {f32(width), f32(height)}
}

window_make :: proc(width, height: f32, name: string, allocator := context.allocator) -> (glfw.WindowHandle, bool) {
	if !bool(glfw.Init()) {
		fmt.eprintln("Failed to initialize GLFW.")
		return nil, false
	}
	csource := strings.clone_to_cstring(name, allocator)
	defer delete(csource)
	window_handle := glfw.CreateWindow(i32(width), i32(height), csource, nil, nil)

	if window_handle == nil {
		fmt.eprintln("Failed to create GLFW window.")
		return nil, false
	}

	glfw.MakeContextCurrent(window_handle)
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	gl.Viewport(0, 0, i32(width), i32(height))
	glfw.SetFramebufferSizeCallback(window_handle, window_size_callback)

	state.app_state.window = {f32(width), f32(height)}

	return window_handle, true
}

window_destroy :: proc(window: glfw.WindowHandle) {
	glfw.DestroyWindow(window)
	glfw.Terminate()
}

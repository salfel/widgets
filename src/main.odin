package main

import "core:fmt"
import gl "vendor:OpenGL"
import "vendor:glfw"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

main :: proc() {
	if !bool(glfw.Init()) {
		fmt.eprintln("Failed to initialize GLFW.")
		return
	}

	window_handle := glfw.CreateWindow(800, 600, "Widgets", nil, nil)

	defer glfw.Terminate()
	defer glfw.DestroyWindow(window_handle)

	if window_handle == nil {
		fmt.eprintln("Failed to create GLFW window.")
		return
	}

	glfw.MakeContextCurrent(window_handle)
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	for !glfw.WindowShouldClose(window_handle) {
		glfw.PollEvents()

		gl.ClearColor(0.8, 0.7, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		glfw.SwapBuffers(window_handle)
	}
}

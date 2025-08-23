package main

import "core:fmt"
import "state"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "widgets"

main :: proc() {
	window_handle, ok := widgets.window_make(800, 600, "widgets")
	if !ok {
		fmt.eprintln("Failed to create window")
		return
	}

	defer widgets.window_destroy(window_handle)

	widget, err := widgets.widget_make({200, 200}, {300, 100})
	if err != .None {
		fmt.eprintln("Failed to create widget")
		return
	}

	for !glfw.WindowShouldClose(window_handle) {
		gl.ClearColor(0.8, 0.7, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		widgets.widget_draw(&widget)

		glfw.SwapBuffers(window_handle)
		glfw.PollEvents()
	}
}

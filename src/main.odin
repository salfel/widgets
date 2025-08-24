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

	parent := widgets.widget_make(200, {}, {1, 0, 0, 1})
	child := widgets.widget_make(100, widgets.layout_make(0, 200, 250), {1, 1, 1, 1})
	child2 := widgets.widget_make(300, widgets.layout_make(0, 200), {.2, .5, 0.5, 1})

	widgets.widget_append_child(&parent, child)
	widgets.widget_append_child(&parent, child2)

	for !glfw.WindowShouldClose(window_handle) {
		gl.ClearColor(0.8, 0.7, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		widgets.layout_measure(&parent.layout)
		widgets.layout_compute(&parent.layout, state.app_state.window.width)
		widgets.layout_arrange(&parent.layout)

		widgets.widget_draw(&parent)

		glfw.SwapBuffers(window_handle)
		glfw.PollEvents()
	}
}

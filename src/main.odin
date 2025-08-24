package main

import "core:fmt"
import "css"
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

	parent_styles := map[css.Property]css.Value{}
	parent_styles[.Height] = 200

	child_styles := map[css.Property]css.Value{}
	child_styles[.Width] = 100
	child_styles[.Height] = 200

	child2_styles := map[css.Property]css.Value{}
	child2_styles[.Width] = 600
	child2_styles[.Height] = 100

	parent := widgets.widget_make(parent_styles, {1, 0, 0, 1})
	child := widgets.widget_make(child_styles, {1, 1, 1, 1})
	child2 := widgets.widget_make(child2_styles, {.2, .5, 0.5, 1})

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

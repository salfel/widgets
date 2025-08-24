package main

import "core:fmt"
import "core:os"
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

	file, _ := os.read_entire_file_from_filename("styles.css")

	err: css.Parser_Error
	state.app_state.css, err = css.parse(string(file))
	if err != .None {
		fmt.println("Failed to parse CSS", err)
		return
	}

	delete(file)

	parent := widgets.widget_make([]string{"parent"})
	child := widgets.widget_make([]string{"child"})
	child2 := widgets.widget_make([]string{"child2"})

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

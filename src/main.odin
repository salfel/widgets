package main

import "core:fmt"
import "core:mem"
import "core:os"
import "css"
import "state"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "widgets"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

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

	defer widgets.widget_destroy(&parent)
	defer widgets.widget_destroy(&child)
	defer widgets.widget_destroy(&child2)

	widgets.widget_append_child(&parent, child)
	widgets.widget_append_child(&parent, child2)

	for !glfw.WindowShouldClose(window_handle) {
		gl.ClearColor(0.8, 0.7, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		widgets.layout_measure(&parent.layout)
		widgets.layout_compute(&parent.layout, state.app_state.window_size.x)
		widgets.layout_arrange(&parent.layout)

		widgets.widget_draw(&parent)

		glfw.SwapBuffers(window_handle)
		glfw.PollEvents()
	}
}

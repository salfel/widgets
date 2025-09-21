package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import "css"
import gl "vendor:OpenGL"
import "vendor:glfw"

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

	window_handle, ok := window_make(800, 600, "widgets")
	if !ok {
		fmt.eprintln("Failed to create window")
		return
	}

	defer window_destroy(window_handle)

	file, _ := os.read_entire_file_from_filename("styles.css", context.temp_allocator)

	err: css.Parser_Error
	app_state.css, err = css.parse(string(file))
	if err != .None {
		fmt.println("Failed to parse CSS", err)
		return
	}

	parent := widget_make([]string{"parent"})
	child := widget_make([]string{"child"})
	child2 := widget_make([]string{"child2"})

	widget_append_child(parent, child)
	widget_append_child(child, child2)

	defer widget_destroy(parent)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	for !glfw.WindowShouldClose(window_handle) {
		gl.ClearColor(0.8, 0.7, 0.3, 1.0)
		gl.ClearStencil(0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		layout_measure(&parent.layout)
		layout_arrange(&parent.layout)

		widget_draw(parent)

		glfw.SwapBuffers(window_handle)
		glfw.PollEvents()
	}
}

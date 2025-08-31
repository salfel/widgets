package main

import "core:c"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "css"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "vendor:stb/image"

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

	app_state.glyph_repository = glyph_repository_make()
	defer glyph_repository_destroy(&app_state.glyph_repository)

	parent := widget_make([]string{"parent"})
	child := widget_make([]string{"child"})
	child2 := widget_make([]string{"child2"})
	child3 := widget_make([]string{"child3"})
	child4 := widget_make([]string{"child4"})

	defer widget_destroy(parent)

	widget_append_child(parent, child)
	widget_append_child(parent, child2)
	widget_append_child(child, child3)
	widget_append_child(child, child4)

	blur_buffer := blur_buffer_make()

	text, _ := text_make("test", "font.ttf", 200, {300, 400})
	defer text_destroy(&text)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	for !glfw.WindowShouldClose(window_handle) {
		blur_buffer_bind(&blur_buffer)

		gl.ClearColor(0.8, 0.7, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		layout_measure(&parent.layout)
		layout_compute(&parent.layout, app_state.window_size.x)
		layout_arrange(&parent.layout)

		widget_draw(parent)

		blur_buffer_render(blur_buffer)

		text_draw(&text)

		glfw.SwapBuffers(window_handle)
		glfw.PollEvents()
	}
}

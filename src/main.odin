package main

import wl "../lib/wayland"
import "core:fmt"
import "core:mem"
import "core:os"
import "css"
import "renderer"
import "state"
import gl "vendor:OpenGL"
import "vendor:egl"
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

	state.app_state.ctx = context

	renderer.renderer_init("widgets", "widgets")

	file, _ := os.read_entire_file_from_filename("styles.css", context.temp_allocator)

	err: css.Parser_Error
	state.app_state.css, err = css.parse(string(file))
	if err != .None {
		fmt.println("Failed to parse CSS", err)
		return
	}

	parent := block_make([]string{"parent"})
	child := block_make([]string{"child"})
	child2 := block_make([]string{"child2"})
	child3 := box_make([]string{"child3"})
	text := text_make("Hello World", "font.ttf", 50, []string{"text"})
	child4 := box_make([]string{"child4"})
	child5 := block_make([]string{"child5"})

	widget_append_child(parent, child)
	widget_append_child(parent, child2)
	widget_append_child(child2, child3)
	widget_append_child(child2, text)
	widget_append_child(child2, child4)
	widget_append_child(child2, child5)

	defer widget_destroy(parent)


	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	for wl.display_dispatch_pending(renderer.g_Renderer.wl_state.display) != -1 {
		gl.ClearColor(0.8, 0.7, 0.3, 1.0)
		gl.ClearStencil(0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		layout_compute(&parent.layout, state.app_state.window_size.x)
		layout_arrange(&parent.layout)

		widget_draw(parent)

		egl.SwapBuffers(renderer.g_Renderer.egl_state.display, renderer.g_Renderer.egl_state.surface)
	}
}

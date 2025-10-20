#+feature dynamic-literals

package main


import wl "../lib/wayland"
import "core:fmt"
import "core:mem"
import "core:os"
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

	renderer_init("widgets", "widgets")

	parent := renderer_register_widget(
		.Block,
		map[Property]Value {
			.Background = Color{0.2, 0.2, 0.2, 1.0},
			.Margin = 20,
			.Rounding = 20,
			.Border = Border{width = 10, color = {1, 1, 0, 1}},
		},
	)
	child := text_make("Hello World", "font.ttf", 50, map[Property]Value{.Color = Color{1, 0, 0, 1}})
	widget_append_child(parent, child)
	defer widget_destroy(parent)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	for wl.display_dispatch_pending(g_Renderer.wl_state.display) != -1 {
		gl.ClearColor(0.8, 0.7, 0.3, 1.0)
		gl.ClearStencil(0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		layout_compute(&parent.layout, g_Renderer.window_size.x)
		layout_arrange(&parent.layout)

		widget_draw(parent)

		egl.SwapBuffers(g_Renderer.egl_state.display, g_Renderer.egl_state.surface)
	}
}

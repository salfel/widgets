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

	parent_id := renderer_register_widget(
		box_make(
			map[Property]Value {
				.Background = Color{0, 0, 0.8, 1.0},
				.Margin = 20,
				.Rounding = 20,
				.Border = Border{width = 10, color = {1, .3, 0.5, 1}},
			},
		),
	)
	renderer_register_child(
		parent_id,
		text_make("Hello World", "font.ttf", 50, map[Property]Value{.Color = Color{.4, 1, .2, 1}}),
	)

	renderer_loop()
}

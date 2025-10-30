package main


import wl "../lib/wayland"
import "core:fmt"
import "core:mem"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:egl"
import "vendor:glfw"

count := 1
renderer: Renderer

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

	renderer_init(&renderer, "widgets", "widgets")

	parent_id := renderer_register_widget(&renderer, box_make())
	box_style_set_width(&renderer, parent_id, 800)
	box_style_set_height(&renderer, parent_id, 700)
	box_style_set_rounding(&renderer, parent_id, 10)
	box_style_set_border(&renderer, parent_id, Border{width = 10, color = RED})
	box_style_set_background(&renderer, parent_id, BLUE)
	box_style_set_margin(&renderer, parent_id, sides_make(30))
	box_style_set_padding(&renderer, parent_id, sides_make(50))

	child1_id, _ := renderer_register_child(&renderer, parent_id, text_make("count: 0", "font.ttf"))
	text_style_set_color(&renderer, child1_id, WHITE)
	text_style_set_font_size(&renderer, child1_id, 96)

	child2_id, _ := renderer_register_child(&renderer, parent_id, box_make())
	box_style_set_width(&renderer, child2_id, 200)
	box_style_set_height(&renderer, child2_id, 200)
	box_style_set_background(&renderer, child2_id, GREEN)
	box_style_set_rounding(&renderer, child2_id, 50)
	box_style_set_margin(&renderer, child2_id, sides_make(10))
	box_style_set_border(&renderer, child2_id, Border{width = 10, color = RED})

	renderer_register_click(&renderer, child1_id, proc(widget: ^Widget, position: [2]f32) {
		text_set_content(&renderer, widget.id, fmt.tprint("count: ", count))
		count += 1
	})

	renderer_loop(&renderer)
}

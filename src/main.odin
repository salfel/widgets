package main

import "core:fmt"
import "core:mem"

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

	app_context: App_Context
	app_context_init(&app_context, "widgets", "widgets")
	defer app_context_destroy(&app_context)

	child1 := text_make("this is a pretty long text, hope this works", "Sans")
	widget_register(child1, &app_context.widget_manager)
	widget_attach_to_viewport(child1, &app_context.widget_manager)
	text_style_set_color(child1, WHITE, &app_context.renderer)
	text_style_set_font_size(child1, 24, &app_context.renderer)

	renderer_loop(&app_context)
}

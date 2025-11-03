package main

import "core:fmt"
import "core:mem"
import "core:os"
import wl "lib:wayland"
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

	app_context: App_Context
	app_context_init(&app_context, "widgets", "widgets")
	defer app_context_destroy(&app_context)

	parent := block_make()
	widget_register(parent, &app_context.widget_manager)
	widget_attach_to_viewport(parent, &app_context.widget_manager)
	box_style_set_height(parent, 700, &app_context.renderer)
	box_style_set_rounding(parent, 10, &app_context.renderer)
	box_style_set_border(parent, Border{width = 10, color = RED}, &app_context.renderer)
	box_style_set_background(parent, BLUE, &app_context.renderer)
	box_style_set_margin(parent, sides_make(30), &app_context.renderer)
	box_style_set_padding(parent, sides_make(50), &app_context.renderer)

	child1 := text_make("count: 0", "font.ttf")
	widget_register(child1, &app_context.widget_manager)
	widget_add_child(parent, child1)
	text_style_set_color(child1, WHITE, &app_context.renderer)
	text_style_set_font_size(child1, 96, &app_context.renderer)

	image := image_make("wallpaper.jpg")
	widget_register(image, &app_context.widget_manager)
	widget_add_child(parent, image)
	image_style_set_width(image, 800, &app_context.renderer)
	image_style_set_height(image, 500, &app_context.renderer)

	count := 1

	widget_set_onclick(child1, proc(widget: ^Widget, position: [2]f32, count: rawptr, app_context: ^App_Context) {
			count := cast(^int)count

			text_set_content(widget, fmt.tprint("count: ", count^), &app_context.renderer)

			count^ += 1
		}, &count)

	renderer_loop(&app_context)
}

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

	parent := box_make()
	widget_register(parent, &app_context.widget_manager)
	widget_attach_to_viewport(parent, &app_context.widget_manager)
	box_set_property(parent, .Expand_Horizontal, &app_context.renderer)
	box_set_property(parent, .Expand_Vertical, &app_context.renderer)
	parent.layout.axis = .Vertical
	box_style_set_rounding(parent, 10, &app_context.renderer)
	box_style_set_border(parent, Border{width = 10, color = RED}, &app_context.renderer)
	box_style_set_background(parent, BLUE, &app_context.renderer)
	box_style_set_margin(parent, sides_make(30), &app_context.renderer)
	box_style_set_padding(parent, sides_make(50), &app_context.renderer)
	box_style_set_background_image(parent, "wallpaper.jpg", &app_context.renderer)

	button := button_make()
	widget_register(button, &app_context.widget_manager)
	widget_add_child(parent, button)
	box_style_set_background(button, {0.15, 0.15, 0.15, 1}, &app_context.renderer)
	box_style_set_rounding(button, 20, &app_context.renderer)
	box_style_set_border(button, Border{width = 10, color = {0.4, 0.4, 0.4, 1}}, &app_context.renderer)
	box_style_set_padding(button, sides_make(32, 32, 20, 20), &app_context.renderer)
	box_set_property(button, .Expand_Vertical, &app_context.renderer)

	child1 := text_make("count: 0", "Sans")
	widget_register(child1, &app_context.widget_manager)
	widget_add_child(button, child1)
	text_style_set_color(child1, WHITE, &app_context.renderer)
	text_style_set_font_size(child1, 96, &app_context.renderer)

	child2 := box_make()
	widget_register(child2, &app_context.widget_manager)
	widget_add_child(parent, child2)
	box_style_set_width(child2, 300, &app_context.renderer)
	box_style_set_background(child2, RED, &app_context.renderer)
	box_style_set_margin(child2, sides_make(0, 0, 20, 20), &app_context.renderer)
	box_style_set_rounding(child2, 20, &app_context.renderer)
	box_style_set_border(child2, Border{width = 10, color = GREEN}, &app_context.renderer)
	box_set_property(child2, .Expand_Vertical, &app_context.renderer)

	child3 := box_make()
	widget_register(child3, &app_context.widget_manager)
	widget_add_child(parent, child3)
	box_style_set_width(child3, 300, &app_context.renderer)
	box_style_set_background(child3, BLUE, &app_context.renderer)
	box_style_set_rounding(child3, 5, &app_context.renderer)
	box_style_set_border(child3, Border{width = 10, color = YELLOW}, &app_context.renderer)
	box_set_property(child3, .Expand_Horizontal, &app_context.renderer)
	box_set_property(child3, .Expand_Vertical, &app_context.renderer)

	count := 1

	button_set_onclick(button, proc(widget: ^Widget, position: [2]f32, count: rawptr, app_context: ^App_Context) {
			count := cast(^int)count

			text_set_content(widget.children[0], fmt.tprint("count: ", count^), &app_context.renderer)

			count^ += 1
		}, &count)

	request_image(&app_context.async_resource_manager, Image_Data{path = "tux.png"})

	renderer_loop(&app_context)
}

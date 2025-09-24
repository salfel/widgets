package main

import "core:fmt"
import "core:math/linalg"
import "css"

Widget_Type :: enum {
	Box,
	Block,
}

Widget :: struct {
	type:     Widget_Type,

	// layout
	layout:   Layout,
	children: [dynamic]^Widget,
	parent:   ^Widget,

	// Rendering
	data:     union {
		Box_Data,
	},
}

widget_make :: proc(
	type: Widget_Type,
	classes: []string,
	allocator := context.allocator,
) -> (
	widget: ^Widget,
	ok: bool,
) #optional_ok {
	widget = new(Widget, allocator)
	widget.children = make([dynamic]^Widget, allocator)
	widget.layout = layout_make(allocator)
	widget.type = type

	styles := make(map[css.Property]css.Value, allocator)
	defer delete(styles)
	for selector in app_state.css.selectors {
		if selector.type != .Class {continue}

		for class in classes {
			if selector.name == class {
				for property, value in selector.declarations {
					styles[property] = value
				}
			}
		}
	}

	layout_apply_styles(&widget.layout, styles)

	switch type {
	case .Box:
		widget.data = box_make(styles, allocator)
		widget.layout.type = .Box
	case .Block:
		widget.data = box_make(styles, allocator)
		widget.layout.type = .Block
	}

	widget.type = type

	return
}

widget_draw :: proc(widget: ^Widget, depth: i32 = 1) {
	switch widget.type {
	case .Box, .Block:
		box_draw(widget, depth)
	}
}

widget_destroy :: proc(widget: ^Widget) {
	for &child in widget.children {
		widget_destroy(child)
	}

	delete(widget.children)
	layout_destroy(&widget.layout)
	free(widget)
}


widget_append_child :: proc(widget: ^Widget, child: ^Widget) {
	child.parent = widget
	append(&widget.children, child)
	append(&widget.layout.children, &child.layout)
}

calculate_mp :: proc(layout: Layout) -> matrix[4, 4]f32 {
	using layout.result

	scale := linalg.matrix4_scale_f32({size.x, size.y, 1})
	translation := linalg.matrix4_translate_f32({position.x, position.y, 0})
	projection := linalg.matrix_ortho3d_f32(0, app_state.window_size.x, app_state.window_size.y, 0, 0, 1)

	return projection * translation * scale
}

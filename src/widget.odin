package main

import "core:math/linalg"

WidgetId :: distinct int

Widget_Type :: enum {
	Viewport,
	Box,
	Block,
	Text,
}

On_Click :: proc(widget: ^Widget, position: [2]f32)

Widget :: struct {
	type:     Widget_Type,
	id:       WidgetId,

	// layout
	layout:   Layout,
	children: [dynamic]WidgetId,
	parent:   WidgetId,
	onclick:  On_Click,

	// Rendering
	data:     union {
		Box_Data,
		Text_Data,
	},
}

widget_make :: proc(allocator := context.allocator) -> Widget {
	return Widget {
		children = make([dynamic]WidgetId, allocator),
		onclick = proc(widget: ^Widget, position: [2]f32) {},
		layout = layout_make(allocator),
	}
}

widget_contains_point :: proc(widget: ^Widget, position: [2]f32) -> bool {
	return(
		position.x >= widget.layout.result.position.x &&
		position.x <= widget.layout.result.position.x + widget.layout.result.size.x &&
		position.y >= widget.layout.result.position.y &&
		position.y <= widget.layout.result.position.y + widget.layout.result.size.y \
	)
}

calculate_mp :: proc(layout: Layout) -> matrix[4, 4]f32 {
	using layout.result

	scale := linalg.matrix4_scale_f32({size.x, size.y, 1})
	translation := linalg.matrix4_translate_f32({position.x, position.y, 0})
	projection := linalg.matrix_ortho3d_f32(0, window_size.x, window_size.y, 0, 0, 1)

	return projection * translation * scale
}

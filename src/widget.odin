package main

import "core:math/linalg"

WidgetId :: distinct int

Widget_Type :: enum {
	Viewport,
	Box,
	Block,
	Text,
}

Widget :: struct {
	type:     Widget_Type,
	id:       WidgetId,

	// layout
	layout:   Layout,
	children: [dynamic]WidgetId,
	parent:   WidgetId,

	// Rendering
	data:     union {
		Box_Data,
		Text_Data,
	},
}

widget_make :: proc(style: Style, allocator := context.allocator) -> Widget {
	return Widget{children = make([dynamic]WidgetId, allocator), layout = layout_make(style, allocator)}
}

calculate_mp :: proc(layout: Layout) -> matrix[4, 4]f32 {
	using layout.result

	scale := linalg.matrix4_scale_f32({size.x, size.y, 1})
	translation := linalg.matrix4_translate_f32({position.x, position.y, 0})
	projection := linalg.matrix_ortho3d_f32(0, g_Renderer.window_size.x, g_Renderer.window_size.y, 0, 0, 1)

	return projection * translation * scale
}

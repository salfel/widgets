package main

import "core:math/linalg"

Widget_Type :: enum {
	Box,
	Block,
	Text,
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
		Text_Data,
	},
}

widget_make :: proc(style: Style, allocator := context.allocator) -> (widget: ^Widget) {
	widget = new(Widget, allocator)
	widget.children = make([dynamic]^Widget, allocator)
	widget.layout = layout_make(style, allocator)

	return
}

widget_draw :: proc(widget: ^Widget, depth: i32 = 1) {
	switch widget.type {
	case .Box, .Block:
		box_draw(widget, depth)
	case .Text:
		text_draw(widget, depth)
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
	projection := linalg.matrix_ortho3d_f32(0, g_Renderer.window_size.x, g_Renderer.window_size.y, 0, 0, 1)

	return projection * translation * scale
}

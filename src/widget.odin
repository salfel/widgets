package main

import "base:intrinsics"
import "core:math/linalg"
import gl "vendor:OpenGL"

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
	children: [dynamic]^Widget,
	parent:   WidgetId,
	data:     union {
		Box,
		Text,
	},

	// internal functions
	draw:     proc(widget: ^Widget, depth: i32 = 1),

	// handlers
	onclick:  On_Click,
}

Widget_Cache :: struct {
	init:                           bool,
	fragment_shader, vertex_shader: u32,
	vao, vbo:                       u32,
}

widget_make :: proc(allocator := context.allocator) -> ^Widget {
	widget := new(Widget)

	widget.children = make([dynamic]^Widget, allocator)
	widget.onclick = proc(widget: ^Widget, position: [2]f32) {}
	widget.layout = layout_make(allocator)

	return widget
}

widget_contains_point :: proc(widget: ^Widget, position: [2]f32) -> bool {
	return(
		position.x >= widget.layout.result.position.x &&
		position.x <= widget.layout.result.position.x + widget.layout.result.size.x &&
		position.y >= widget.layout.result.position.y &&
		position.y <= widget.layout.result.position.y + widget.layout.result.size.y \
	)
}

widget_add_child :: proc(parent: ^Widget, child: ^Widget) {
	append(&parent.children, child)
	append(&parent.layout.children, &child.layout)
	child.parent = parent.id
}

calculate_mp :: proc(layout: Layout) -> matrix[4, 4]f32 {
	using layout.result

	scale := linalg.matrix4_scale_f32({size.x, size.y, 1})
	translation := linalg.matrix4_translate_f32({position.x, position.y, 0})
	projection := linalg.matrix_ortho3d_f32(0, window_size.x, window_size.y, 0, 0, 1)

	return projection * translation * scale
}

widget_cache_destroy :: proc "contextless" (widget_cache: ^Widget_Cache) {
	gl.DeleteBuffers(1, &widget_cache.vbo)
	gl.DeleteVertexArrays(1, &widget_cache.vao)
	gl.DeleteShader(widget_cache.fragment_shader)
	gl.DeleteShader(widget_cache.vertex_shader)
}

package main

import "base:intrinsics"
import "core:fmt"
import "core:math/linalg"
import gl "vendor:OpenGL"

WidgetId :: distinct int

Widget_Type :: enum {
	Box,
	Block,
	Text,
	Image,
	Button,
}

Handler :: struct($T: typeid) where intrinsics.type_is_proc(T) {
	handler: T,
	data:    rawptr,
}

On_Click :: proc(widget: ^Widget, position: [2]f32, user_ptr: rawptr, app_context: ^App_Context)

Widget :: struct {
	type:           Widget_Type,
	id:             WidgetId,

	// layout
	layout:         Layout,
	children:       [dynamic]^Widget,
	allow_children: bool,
	parent:         ^Widget,
	data:           union {
		Box,
		Text,
		Image,
	},

	// internal functions
	draw:           proc(widget: ^Widget, app_context: ^App_Context, depth: i32 = 1),
	recalculate_mp: proc(widget: ^Widget, app_context: ^App_Context),
	destroy:        proc(widget: ^Widget),

	// handlers
	on_click:       Handler(On_Click),
}

Widget_Cache :: struct {
	init:                           bool,
	fragment_shader, vertex_shader: u32,
	vao, vbo:                       u32,
}

Widget_Manager :: struct {
	widget_id: WidgetId,
	viewport:  ^Widget,
	widgets:   map[WidgetId]^Widget,
}

widget_manager_init :: proc(widget_manager: ^Widget_Manager, allocator := context.allocator) {
	ok: bool
	widget_manager.viewport, ok = box_make()
	assert(ok, "Failed to create viewport")
	widget_manager.viewport.id = 0

	widget_manager.widget_id = 1
	widget_manager.widgets = make(map[WidgetId]^Widget, allocator)
}

widget_manager_destroy :: proc(widget_manager: ^Widget_Manager) {
	for _, widget in widget_manager.widgets {
		widget_destroy(widget)
	}

	widget_destroy(widget_manager.viewport)
	delete(widget_manager.widgets)
}

widget_register :: proc(widget: ^Widget, widget_manager: ^Widget_Manager) {
	widget.id = widget_manager.widget_id
	widget_manager.widgets[widget.id] = widget

	widget_manager.widget_id += 1
}

widget_add_child :: proc(parent: ^Widget, child: ^Widget) {
	if !parent.allow_children {
		fmt.eprintln("can't add children to widget of type", parent.type)
		return
	}

	append(&parent.children, child)
	append(&parent.layout.children, &child.layout)

	child.parent = parent
}

widget_get :: proc(id: WidgetId, widget_manager: ^Widget_Manager) -> (^Widget, bool) {
	return widget_manager.widgets[id]
}

widget_attach_to_viewport :: proc(widget: ^Widget, widget_manager: ^Widget_Manager) {
	widget_add_child(widget_manager.viewport, widget)
}

widget_make :: proc(allocator := context.allocator) -> ^Widget {
	widget := new(Widget)

	widget.children = make([dynamic]^Widget, allocator)
	widget.on_click = {
		handler = nil,
		data    = nil,
	}
	widget.layout = layout_make(allocator)

	return widget
}

widget_destroy :: proc(widget: ^Widget) {
	if widget.destroy != nil do widget->destroy()

	delete(widget.layout.children)
	delete(widget.children)
	free(widget)
}

widget_contains_point :: proc(widget: ^Widget, position: [2]f32) -> bool {
	return(
		position.x >= widget.layout.position.x &&
		position.x <= widget.layout.position.x + widget.layout.size.x &&
		position.y >= widget.layout.position.y &&
		position.y <= widget.layout.position.y + widget.layout.size.y \
	)
}

calculate_mp :: proc(layout: Layout, app_context: ^App_Context) -> matrix[4, 4]f32 {
	using layout

	scale := linalg.matrix4_scale_f32({size.x, size.y, 1})
	translation := linalg.matrix4_translate_f32({position.x, position.y, 0})
	projection := linalg.matrix_ortho3d_f32(0, app_context.window.size.x, app_context.window.size.y, 0, 0, 1)

	return projection * translation * scale
}

widget_cache_destroy :: proc "contextless" (widget_cache: ^Widget_Cache) {
	gl.DeleteBuffers(1, &widget_cache.vbo)
	gl.DeleteVertexArrays(1, &widget_cache.vao)
	gl.DeleteShader(widget_cache.fragment_shader)
	gl.DeleteShader(widget_cache.vertex_shader)
}

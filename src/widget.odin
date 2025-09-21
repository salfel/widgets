package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:testing"
import "core:time"
import "css"
import gl "vendor:OpenGL"

VERTEX_SHADER :: #load("shaders/vertex.glsl", string)
FRAGMENT_SHADER :: #load("shaders/fragment.glsl", string)

Border :: css.Border


Widget :: struct {
	// render
	color:                                        [4]f32,
	border:                                       Border,
	border_radius:                                f32,
	mp:                                           matrix[4, 4]f32,
	last_window_size:                             [2]f32,

	// layout
	children:                                     [dynamic]^Widget,
	parent:                                       ^Widget,
	layout:                                       Layout,

	// OpenGL stuff
	program, vao:                                 u32,
	mvp_location, size_location, color_location:  i32,
	border_width_location, border_color_location: i32,
	border_radius_location:                       i32,
	is_stencil_location:                          i32,
}

widget_make :: proc(classes: []string, allocator := context.allocator) -> (widget: ^Widget, ok: bool) #optional_ok {
	widget = new(Widget, allocator)
	widget.children = make([dynamic]^Widget, allocator)
	widget.layout = layout_make(allocator)

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

	widget_apply_styles(widget, styles)

	VERTICES := []f32{0, 0, 1, 0, 0, 1, 1, 1}

	vertex_shader := compile_shader(gl.VERTEX_SHADER, VERTEX_SHADER) or_return
	fragment_shader := compile_shader(gl.FRAGMENT_SHADER, FRAGMENT_SHADER) or_return

	widget.program = create_program(vertex_shader, fragment_shader) or_return

	vbo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenVertexArrays(1, &widget.vao)
	gl.BindVertexArray(widget.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(VERTICES) * size_of(f32), &VERTICES[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	gl.UseProgram(widget.program)
	widget.mvp_location = gl.GetUniformLocation(widget.program, "MVP")
	widget.color_location = gl.GetUniformLocation(widget.program, "color")
	widget.size_location = gl.GetUniformLocation(widget.program, "size")
	widget.border_width_location = gl.GetUniformLocation(widget.program, "border_width")
	widget.border_color_location = gl.GetUniformLocation(widget.program, "border_color")
	widget.border_radius_location = gl.GetUniformLocation(widget.program, "border_radius")
	widget.is_stencil_location = gl.GetUniformLocation(widget.program, "is_stencil")
	gl.UseProgram(0)

	return
}

widget_destroy :: proc(widget: ^Widget) {
	for &child in widget.children {
		widget_destroy(child)
	}

	delete(widget.children)
	layout_destroy(&widget.layout)
	free(widget)
}


widget_draw :: proc(widget: ^Widget, depth: i32 = 1) {
	gl.UseProgram(widget.program)

	calculate_mp(widget)

	gl.UniformMatrix4fv(widget.mvp_location, 1, false, linalg.matrix_to_ptr(&widget.mp))
	gl.Uniform4fv(widget.color_location, 1, linalg.vector_to_ptr(&widget.color))
	gl.Uniform1f(widget.border_width_location, widget.border.width)
	gl.Uniform3fv(widget.border_color_location, 1, linalg.vector_to_ptr(&widget.border.color))
	gl.Uniform2fv(widget.size_location, 1, linalg.vector_to_ptr(&widget.layout.result.size))
	gl.Uniform1f(widget.border_radius_location, widget.border_radius)
	gl.Uniform1i(widget.is_stencil_location, 0)

	if depth == 1 {
		gl.Enable(gl.STENCIL_TEST)
	}

	gl.ColorMask(true, true, true, true)
	gl.StencilMask(0x00)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.KEEP)

	gl.BindVertexArray(widget.vao)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.ColorMask(false, false, false, false)
	gl.StencilMask(0xFF)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.INCR)

	gl.UseProgram(widget.program)
	gl.Uniform1i(widget.is_stencil_location, 1)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
	gl.BindVertexArray(0)
	gl.UseProgram(0)

	for &child in widget.children {
		widget_draw(child, depth + 1)
	}

	if depth == 1 {
		gl.Disable(gl.STENCIL_TEST)
		gl.ColorMask(true, true, true, true)
		gl.StencilMask(0xFF)
		gl.StencilFunc(gl.EQUAL, 1, 0xFF)
		gl.StencilOp(gl.KEEP, gl.KEEP, gl.KEEP)
	}

	gl.BindVertexArray(0)
	gl.UseProgram(0)
}

widget_append_child :: proc(widget: ^Widget, child: ^Widget) {
	child.parent = widget
	append(&widget.children, child)
	append(&widget.layout.children, &child.layout)
}

calculate_mp :: proc(widget: ^Widget) {
	if app_state.window_size == widget.last_window_size {
		return
	}

	size := widget.layout.result.size
	position := widget.layout.result.position

	scale := linalg.matrix4_scale_f32({size.x, size.y, 1})
	translation := linalg.matrix4_translate_f32({position.x, position.y, 0})
	projection := linalg.matrix_ortho3d_f32(0, app_state.window_size.x, app_state.window_size.y, 0, 0, 1)

	widget.mp = projection * translation * scale

	widget.last_window_size = app_state.window_size
}

widget_apply_styles :: proc(widget: ^Widget, styles: map[css.Property]css.Value) {
	if height, ok := styles[.Height]; ok {
		widget.layout.height, ok = height.(f32)
		assert(ok, "Expected height to be a number")
	}

	if width, ok := styles[.Width]; ok {
		widget.layout.width, ok = width.(f32)
		assert(ok, "Expected width to be a number")
	}

	if color, ok := styles[.Color]; ok {
		col, ok := color.([3]f32)
		widget.color = [4]f32{col[0], col[1], col[2], 1}
		assert(ok, "Expected color to be a color vec")
	}

	if padding_left, ok := styles[.Padding_Left]; ok {
		widget.layout.padding.left, ok = padding_left.(f32)
		assert(ok, "Expected padding-left to be a number")
	}

	if padding_right, ok := styles[.Padding_Right]; ok {
		widget.layout.padding.right, ok = padding_right.(f32)
		assert(ok, "Expected padding-right to be a number")
	}

	if padding_top, ok := styles[.Padding_Top]; ok {
		widget.layout.padding.top, ok = padding_top.(f32)
		assert(ok, "Expected padding-top to be a number")
	}

	if padding_bottom, ok := styles[.Padding_Bottom]; ok {
		widget.layout.padding.bottom, ok = padding_bottom.(f32)
		assert(ok, "Expected padding-bottom to be a number")
	}

	if margin_left, ok := styles[.Margin_Left]; ok {
		widget.layout.margin.left, ok = margin_left.(f32)
		assert(ok, "Expected margin-left to be a number")
	}

	if margin_right, ok := styles[.Margin_Right]; ok {
		widget.layout.margin.right, ok = margin_right.(f32)
		assert(ok, "Expected margin-right to be a number")
	}

	if margin_top, ok := styles[.Margin_Top]; ok {
		widget.layout.margin.top, ok = margin_top.(f32)
		assert(ok, "Expected margin-top to be a number")
	}

	if margin_bottom, ok := styles[.Margin_Bottom]; ok {
		widget.layout.margin.bottom, ok = margin_bottom.(f32)
		assert(ok, "Expected margin-bottom to be a number")
	}

	if border, ok := styles[.Border]; ok {
		widget.border, ok = border.(Border)
		widget.layout.border = edges_make(widget.border.width)
		assert(ok, "Expected border to be a Border")
	}

	if border_radius, ok := styles[.Border_Radius]; ok {
		widget.border_radius, ok = border_radius.(f32)
		assert(ok, "Expected border-radius to be a number")
	}
}

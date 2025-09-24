package main

import "core:math"
import "core:math/linalg"
import "core:testing"
import "css"
import gl "vendor:OpenGL"

VERTEX_SHADER :: #load("shaders/vertex.glsl", string)
FRAGMENT_SHADER :: #load("shaders/fragment.glsl", string)

Border :: css.Border

Box_Data :: struct {
	// render
	color:                                        [4]f32,
	border:                                       Border,
	border_radius:                                f32,
	mp:                                           matrix[4, 4]f32,
	last_window_size:                             [2]f32,

	// OpenGL stuff
	program, vao:                                 u32,
	mvp_location, size_location, color_location:  i32,
	border_width_location, border_color_location: i32,
	border_radius_location:                       i32,
	is_stencil_location:                          i32,
}

box_make :: proc(
	styles: map[css.Property]css.Value,
	allocator := context.allocator,
) -> (
	box_data: Box_Data,
	ok: bool,
) #optional_ok {
	box_apply_styles(&box_data, styles)

	VERTICES := []f32{0, 0, 1, 0, 0, 1, 1, 1}

	vertex_shader := compile_shader(gl.VERTEX_SHADER, VERTEX_SHADER) or_return
	fragment_shader := compile_shader(gl.FRAGMENT_SHADER, FRAGMENT_SHADER) or_return

	box_data.program = create_program(vertex_shader, fragment_shader) or_return

	vbo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenVertexArrays(1, &box_data.vao)
	gl.BindVertexArray(box_data.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(VERTICES) * size_of(f32), &VERTICES[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	gl.UseProgram(box_data.program)
	box_data.mvp_location = gl.GetUniformLocation(box_data.program, "MVP")
	box_data.color_location = gl.GetUniformLocation(box_data.program, "color")
	box_data.size_location = gl.GetUniformLocation(box_data.program, "size")
	box_data.border_width_location = gl.GetUniformLocation(box_data.program, "border_width")
	box_data.border_color_location = gl.GetUniformLocation(box_data.program, "border_color")
	box_data.border_radius_location = gl.GetUniformLocation(box_data.program, "border_radius")
	box_data.is_stencil_location = gl.GetUniformLocation(box_data.program, "is_stencil")
	gl.UseProgram(0)

	return
}


box_draw :: proc(widget: ^Widget, depth: i32 = 1) {
	box_data, ok := &widget.data.(Box_Data)
	assert(ok, "Expected Box_Data")

	gl.UseProgram(box_data.program)

	box_data.mp = calculate_mp(widget.layout)

	gl.UniformMatrix4fv(box_data.mvp_location, 1, false, linalg.matrix_to_ptr(&box_data.mp))
	gl.Uniform4fv(box_data.color_location, 1, linalg.vector_to_ptr(&box_data.color))
	gl.Uniform1f(box_data.border_width_location, box_data.border.width)
	gl.Uniform3fv(box_data.border_color_location, 1, linalg.vector_to_ptr(&box_data.border.color))
	gl.Uniform2fv(box_data.size_location, 1, linalg.vector_to_ptr(&widget.layout.result.size))
	gl.Uniform1f(box_data.border_radius_location, box_data.border_radius)
	gl.Uniform1i(box_data.is_stencil_location, 0)

	if depth == 1 {
		gl.Enable(gl.STENCIL_TEST)
	}

	gl.ColorMask(true, true, true, true)
	gl.StencilMask(0x00)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.KEEP)

	gl.BindVertexArray(box_data.vao)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.ColorMask(false, false, false, false)
	gl.StencilMask(0xFF)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.INCR)

	gl.UseProgram(box_data.program)
	gl.Uniform1i(box_data.is_stencil_location, 1)
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

box_apply_styles :: proc(box_data: ^Box_Data, styles: map[css.Property]css.Value) {
	if color, ok := styles[.Color]; ok {
		col, ok := color.([3]f32)
		box_data.color = [4]f32{col[0], col[1], col[2], 1}
		assert(ok, "Expected color to be a color vec")
	}
	if border, ok := styles[.Border]; ok {
		box_data.border, ok = border.(Border)
		assert(ok, "Expected border to be a Border")
	}

	if border_radius, ok := styles[.Border_Radius]; ok {
		box_data.border_radius, ok = border_radius.(f32)
		assert(ok, "Expected border-radius to be a number")
	}
}

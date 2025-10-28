package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import gl "vendor:OpenGL"

VERTEX_SHADER :: #load("shaders/vertex.glsl", string)
FRAGMENT_SHADER :: #load("shaders/fragment.glsl", string)

Box_Data :: struct {
	// render
	style:                                        Box_Style,
	mp:                                           matrix[4, 4]f32,
	last_window_size:                             [2]f32,

	// OpenGL stuff
	program, vao:                                 u32,
	mvp_location, size_location, color_location:  i32,
	border_width_location, border_color_location: i32,
	border_radius_location:                       i32,
	is_stencil_location:                          i32,
	uniforms:                                     Box_Uniforms,
}

Box_Uniform :: enum {
	Size,
	Background,
	Rounding,
	Border,
}
Box_Uniforms :: bit_set[Box_Uniform]

box_make :: proc(allocator := context.allocator) -> (widget: Widget, ok: bool = true) #optional_ok {
	widget = widget_make(allocator)
	widget.type = .Box
	widget.layout.type = .Box

	widget.data = Box_Data{}
	box_data := &widget.data.(Box_Data)
	box_data.uniforms = Box_Uniforms{.Size, .Background, .Rounding, .Border}

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


box_draw :: proc(renderer: ^Renderer, widget: ^Widget, depth: i32 = 1) {
	box_data, ok := &widget.data.(Box_Data)
	assert(ok, "Expected Box_Data")

	gl.UseProgram(box_data.program)

	for uniform in box_data.uniforms {
		switch uniform {
		case .Size:
			box_data.mp = calculate_mp(widget.layout)
			gl.UniformMatrix4fv(box_data.mvp_location, 1, false, linalg.matrix_to_ptr(&box_data.mp))
			gl.Uniform2fv(box_data.size_location, 1, linalg.vector_to_ptr(&widget.layout.result.size))
			box_data.uniforms -= {.Size}
		case .Background:
			gl.Uniform4fv(box_data.color_location, 1, linalg.vector_to_ptr(&box_data.style.background))
			box_data.uniforms -= {.Background}
		case .Rounding:
			gl.Uniform1f(box_data.border_radius_location, box_data.style.rounding)
			box_data.uniforms -= {.Rounding}
		case .Border:
			gl.Uniform1f(box_data.border_width_location, box_data.style.border.width)
			gl.Uniform3fv(box_data.border_color_location, 1, linalg.vector_to_ptr(&box_data.style.border.color))
			box_data.uniforms -= {.Border}
		}
	}

	box_data.mp = calculate_mp(widget.layout)

	// implement ubo
	gl.UniformMatrix4fv(box_data.mvp_location, 1, false, linalg.matrix_to_ptr(&box_data.mp))
	gl.Uniform4fv(box_data.color_location, 1, linalg.vector_to_ptr(&box_data.style.background))
	gl.Uniform1f(box_data.border_width_location, box_data.style.border.width)
	gl.Uniform3fv(box_data.border_color_location, 1, linalg.vector_to_ptr(&box_data.style.border.color))
	gl.Uniform2fv(box_data.size_location, 1, linalg.vector_to_ptr(&widget.layout.result.size))
	gl.Uniform1f(box_data.border_radius_location, box_data.style.rounding)
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

	for child in widget.children {
		ok := renderer_draw_widget(renderer, child, depth + 1)
		assert(ok, fmt.tprint("Couldn't draw child:", child))
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

box_style_set_width :: proc(renderer: ^Renderer, id: WidgetId, width: f32) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box_data := (&widget.data.(Box_Data)) or_return
	widget.layout.style.width = width
	box_data.uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_height :: proc(renderer: ^Renderer, id: WidgetId, height: f32) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box_data := (&widget.data.(Box_Data)) or_return
	widget.layout.style.height = height
	box_data.uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_margin :: proc(renderer: ^Renderer, id: WidgetId, margin: Sides) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box_data := (&widget.data.(Box_Data)) or_return
	widget.layout.style.margin = margin
	box_data.uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_padding :: proc(renderer: ^Renderer, id: WidgetId, padding: Sides) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box_data := (&widget.data.(Box_Data)) or_return
	widget.layout.style.padding = padding
	box_data.uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_border :: proc(renderer: ^Renderer, id: WidgetId, border: Border) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box_data := (&widget.data.(Box_Data)) or_return
	box_data.style.border = border
	widget.layout.style.border = border
	box_data.uniforms += {.Border, .Size}

	renderer.dirty = true

	return true
}

box_style_set_background :: proc(renderer: ^Renderer, id: WidgetId, color: Color) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box_data := (&widget.data.(Box_Data)) or_return
	box_data.style.background = color
	box_data.uniforms += {.Background}

	return true
}

box_style_set_rounding :: proc(renderer: ^Renderer, id: WidgetId, rounding: f32) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box_data := (&widget.data.(Box_Data)) or_return
	box_data.style.rounding = rounding
	box_data.uniforms += {.Rounding}

	return true
}

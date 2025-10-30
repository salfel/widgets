package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import gl "vendor:OpenGL"

VERTEX_SHADER :: #load("shaders/vertex.glsl", string)
FRAGMENT_SHADER :: #load("shaders/fragment.glsl", string)

Box_Manager :: struct {
	init:                           bool,
	vertex_shader, fragment_shader: u32,
	vao, vbo:                       u32,
}

box_manager: Box_Manager

Box :: struct {
	using widget:                                 Widget,

	// render
	style:                                        Box_Style,
	mp:                                           matrix[4, 4]f32,
	last_window_size:                             [2]f32,

	// OpenGL stuff
	program:                                      u32,
	mp_location, size_location, color_location:   i32,
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

box_make :: proc(allocator := context.allocator) -> (box: ^Box, ok: bool = true) #optional_ok {
	box = new(Box)
	box.widget = widget_make(allocator)
	box.widget.type = .Box
	box.widget.layout.type = .Box

	box.style = DEFAULT_BOX_STYLE
	box.uniforms = Box_Uniforms{.Size, .Background, .Rounding, .Border}

	if !box_manager.init {
		box_manager_init() or_return
	}

	box.program = create_program(box_manager.vertex_shader, box_manager.fragment_shader) or_return

	gl.UseProgram(box.program)
	box.mp_location = gl.GetUniformLocation(box.program, "MP")
	box.color_location = gl.GetUniformLocation(box.program, "color")
	box.size_location = gl.GetUniformLocation(box.program, "size")
	box.border_width_location = gl.GetUniformLocation(box.program, "border_width")
	box.border_color_location = gl.GetUniformLocation(box.program, "border_color")
	box.border_radius_location = gl.GetUniformLocation(box.program, "border_radius")
	box.is_stencil_location = gl.GetUniformLocation(box.program, "is_stencil")
	gl.UseProgram(0)

	return
}


box_draw :: proc(renderer: ^Renderer, box: ^Box, depth: i32 = 1) {
	gl.UseProgram(box.program)

	for uniform in box.uniforms {
		switch uniform {
		case .Size:
			box.mp = calculate_mp(box.widget.layout)
			gl.UniformMatrix4fv(box.mp_location, 1, false, linalg.matrix_to_ptr(&box.mp))
			gl.Uniform2fv(box.size_location, 1, linalg.vector_to_ptr(&box.widget.layout.result.size))
			box.uniforms -= {.Size}
		case .Background:
			gl.Uniform4fv(box.color_location, 1, linalg.vector_to_ptr(&box.style.background))
			box.uniforms -= {.Background}
		case .Rounding:
			gl.Uniform1f(box.border_radius_location, box.style.rounding)
			box.uniforms -= {.Rounding}
		case .Border:
			gl.Uniform1f(box.border_width_location, box.style.border.width)
			gl.Uniform4fv(box.border_color_location, 1, linalg.vector_to_ptr(&box.style.border.color))
			box.uniforms -= {.Border}
		}
	}

	gl.Uniform1i(box.is_stencil_location, 0)

	if depth == 1 {
		gl.Enable(gl.STENCIL_TEST)
	}

	gl.ColorMask(true, true, true, true)
	gl.StencilMask(0x00)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.KEEP)

	gl.BindVertexArray(box_manager.vao)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.ColorMask(false, false, false, false)
	gl.StencilMask(0xFF)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.INCR)

	gl.UseProgram(box.program)
	gl.Uniform1i(box.is_stencil_location, 1)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
	gl.BindVertexArray(0)
	gl.UseProgram(0)

	for child in box.widget.children {
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

box_style_set_width :: proc(renderer: ^Renderer, id: WidgetId, width: f32, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (widget.(^Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	box.widget.layout.style.width = width
	box.uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_height :: proc(renderer: ^Renderer, id: WidgetId, height: f32, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (widget.(^Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	box.widget.layout.style.height = height
	box.uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_margin :: proc(renderer: ^Renderer, id: WidgetId, margin: Sides, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (widget.(^Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	box.widget.layout.style.margin = margin
	box.uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_padding :: proc(renderer: ^Renderer, id: WidgetId, padding: Sides, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (widget.(^Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	box.widget.layout.style.padding = padding
	box.uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_border :: proc(renderer: ^Renderer, id: WidgetId, border: Border, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (widget.(^Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	box.style.border = border
	box.widget.layout.style.border = border
	box.uniforms += {.Border, .Size}

	renderer.dirty = true

	return true
}

box_style_set_background :: proc(renderer: ^Renderer, id: WidgetId, color: Color, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (widget.(^Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	box.style.background = color
	box.uniforms += {.Background}

	return true
}

box_style_set_rounding :: proc(renderer: ^Renderer, id: WidgetId, rounding: f32, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (widget.(^Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	box.style.rounding = rounding
	box.uniforms += {.Rounding}

	return true
}

box_manager_init :: proc() -> bool {
	VERTICES := []f32{0, 0, 1, 0, 0, 1, 1, 1}

	box_manager.vertex_shader = compile_shader(gl.VERTEX_SHADER, VERTEX_SHADER) or_return
	box_manager.fragment_shader = compile_shader(gl.FRAGMENT_SHADER, FRAGMENT_SHADER) or_return

	vbo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenVertexArrays(1, &box_manager.vao)
	gl.BindVertexArray(box_manager.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(VERTICES) * size_of(f32), &VERTICES[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	box_manager.init = true

	return true
}

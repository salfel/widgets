package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import gl "vendor:OpenGL"

VERTEX_SHADER :: #load("shaders/vertex.glsl", string)
FRAGMENT_SHADER :: #load("shaders/fragment.glsl", string)

box_cache: Widget_Cache

Box :: struct {
	style:             Box_Style,

	// OpenGL stuff
	program:           u32,
	mp:                matrix[4, 4]f32,
	uniform_locations: struct {
		mp, size, color, border_width, border_color, border_radius, is_stencil: i32,
	},
	pending_uniforms:  Box_Uniforms,
}

Box_Uniform :: enum {
	Size,
	Background,
	Rounding,
	Border,
}
Box_Uniforms :: bit_set[Box_Uniform]

box_make :: proc(allocator := context.allocator) -> (widget: ^Widget, ok: bool = true) #optional_ok {
	widget = widget_make(allocator)
	widget.type = .Box
	widget.layout.type = .Box
	widget.draw = box_draw
	widget.data = Box{}

	box := &widget.data.(Box)
	box.style = DEFAULT_BOX_STYLE
	box.pending_uniforms = Box_Uniforms{.Size, .Background, .Rounding, .Border}

	if !box_cache.init {
		box_cache_init() or_return
	}

	box.program = create_program(box_cache.vertex_shader, box_cache.fragment_shader) or_return

	gl.UseProgram(box.program)
	box.uniform_locations = {
		mp            = gl.GetUniformLocation(box.program, "MP"),
		color         = gl.GetUniformLocation(box.program, "color"),
		size          = gl.GetUniformLocation(box.program, "size"),
		border_width  = gl.GetUniformLocation(box.program, "border_width"),
		border_color  = gl.GetUniformLocation(box.program, "border_color"),
		border_radius = gl.GetUniformLocation(box.program, "border_radius"),
		is_stencil    = gl.GetUniformLocation(box.program, "is_stencil"),
	}
	gl.UseProgram(0)

	return
}


box_draw :: proc(widget: ^Widget, depth: i32 = 1) {
	box, ok := (&widget.data.(Box))
	if !ok {
		fmt.println("invalid widget type, expected Box, got:", widget.type)
		return
	}

	gl.UseProgram(box.program)

	for uniform in box.pending_uniforms {
		switch uniform {
		case .Size:
			box.mp = calculate_mp(widget.layout)
			gl.UniformMatrix4fv(box.uniform_locations.mp, 1, false, linalg.matrix_to_ptr(&box.mp))
			gl.Uniform2fv(box.uniform_locations.size, 1, linalg.vector_to_ptr(&widget.layout.result.size))
			box.pending_uniforms -= {.Size}
		case .Background:
			gl.Uniform4fv(box.uniform_locations.color, 1, linalg.vector_to_ptr(&box.style.background))
			box.pending_uniforms -= {.Background}
		case .Rounding:
			gl.Uniform1f(box.uniform_locations.border_radius, box.style.rounding)
			box.pending_uniforms -= {.Rounding}
		case .Border:
			gl.Uniform1f(box.uniform_locations.border_width, box.style.border.width)
			gl.Uniform4fv(box.uniform_locations.border_color, 1, linalg.vector_to_ptr(&box.style.border.color))
			box.pending_uniforms -= {.Border}
		}
	}

	gl.Uniform1i(box.uniform_locations.is_stencil, 0)

	if depth == 1 {
		gl.Enable(gl.STENCIL_TEST)
	}

	gl.ColorMask(true, true, true, true)
	gl.StencilMask(0x00)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.KEEP)

	gl.BindVertexArray(box_cache.vao)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.ColorMask(false, false, false, false)
	gl.StencilMask(0xFF)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.INCR)

	gl.UseProgram(box.program)
	gl.Uniform1i(box.uniform_locations.is_stencil, 1)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
	gl.BindVertexArray(0)
	gl.UseProgram(0)

	for child in widget.children {
		child->draw(depth + 1)
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
	box, ok := (&widget.data.(Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	widget.layout.style.width = width
	box.pending_uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_height :: proc(renderer: ^Renderer, id: WidgetId, height: f32, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (&widget.data.(Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	widget.layout.style.height = height
	box.pending_uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_margin :: proc(renderer: ^Renderer, id: WidgetId, margin: Sides, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (&widget.data.(Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	widget.layout.style.margin = margin
	box.pending_uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_padding :: proc(renderer: ^Renderer, id: WidgetId, padding: Sides, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (&widget.data.(Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	widget.layout.style.padding = padding
	box.pending_uniforms += {.Size}

	renderer.dirty = true

	return true
}

box_style_set_border :: proc(renderer: ^Renderer, id: WidgetId, border: Border, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (&widget.data.(Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	widget.layout.style.border = border
	box.style.border = border
	box.pending_uniforms += {.Border, .Size}

	renderer.dirty = true

	return true
}

box_style_set_background :: proc(renderer: ^Renderer, id: WidgetId, color: Color, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (&widget.data.(Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	box.style.background = color
	box.pending_uniforms += {.Background}

	return true
}

box_style_set_rounding :: proc(renderer: ^Renderer, id: WidgetId, rounding: f32, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	box, ok := (&widget.data.(Box))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	box.style.rounding = rounding
	box.pending_uniforms += {.Rounding}

	return true
}

box_cache_init :: proc() -> bool {
	VERTICES := []f32{0, 0, 1, 0, 0, 1, 1, 1}

	box_cache.vertex_shader = compile_shader(gl.VERTEX_SHADER, VERTEX_SHADER) or_return
	box_cache.fragment_shader = compile_shader(gl.FRAGMENT_SHADER, FRAGMENT_SHADER) or_return

	vbo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenVertexArrays(1, &box_cache.vao)
	gl.BindVertexArray(box_cache.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(VERTICES) * size_of(f32), &VERTICES[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	box_cache.init = true

	return true
}

@(fini)
box_cache_destroy :: proc "contextless" () {
	widget_cache_destroy(&box_cache)
}

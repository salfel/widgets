package main

import "core:math/linalg"
import gl "vendor:OpenGL"

RECT_VERTEX_SHADER :: #load("shaders/rect/vertex.glsl", cstring)
RECT_FRAGMENT_SHADER :: #load("shaders/rect/fragment.glsl", cstring)

rect_cache: Cache

Rect :: struct {
	// internal
	mp:                matrix[4, 4]f32,
	layout:            Layout,
	color:             Color,

	// opengl
	program:           u32,
	uniform_locations: [Rect_Uniform]i32,
	pending_uniforms:  bit_set[Rect_Uniform],
}

Rect_Uniform :: enum {
	MP,
	Color,
}

rect_make :: proc(size: [2]f32, color: Color) -> Rect {
	cache_init(&rect_cache, RECT_VERTEX_SHADER, RECT_FRAGMENT_SHADER)

	rect := Rect{}

	rect.program, _ = create_program(rect_cache.vertex_shader, rect_cache.fragment_shader)

	rect.layout.style.size.x = layout_constraint_make(size.x)
	rect.layout.style.size.y = layout_constraint_make(size.y)

	rect.uniform_locations = {
		.MP    = gl.GetUniformLocation(rect.program, "MP"),
		.Color = gl.GetUniformLocation(rect.program, "color"),
	}

	rect.color = color

	return rect
}

rect_destroy :: proc(rect: ^Rect) {
	gl.DeleteProgram(rect.program)
	layout_destroy(&rect.layout)
}

rect_draw :: proc(rect: ^Rect) {
	gl.UseProgram(rect.program)

	gl.UniformMatrix4fv(rect.uniform_locations[.MP], 1, false, linalg.matrix_to_ptr(&rect.mp))
	gl.Uniform4fv(rect.uniform_locations[.Color], 1, linalg.vector_to_ptr(&rect.color))

	gl.BindVertexArray(rect_cache.vao)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
	gl.BindVertexArray(0)

	gl.UseProgram(0)
}

rect_recalculate_mp :: proc(rect: ^Rect, app_context: ^App_Context) {
	rect.mp = calculate_mp(rect.layout, app_context)
	rect.pending_uniforms += {.MP}
}

@(fini)
rect_cache_destroy :: proc "contextless" () {
	cache_destroy(&rect_cache)
}

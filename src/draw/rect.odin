package draw

import "core:math/linalg"
import gl "vendor:OpenGL"

RECT_VERTEX_SHADER :: #load("../shaders/rect/vertex.glsl", cstring)
RECT_FRAGMENT_SHADER :: #load("../shaders/rect/fragment.glsl", cstring)

rect_cache: Cache

Rect :: struct {
	// opengl
	program:           u32,
	uniform_locations: struct {
		mp: i32,
	},

	// internal
	mp:                matrix[4, 4]f32,
}

rect_make :: proc() -> Rect {
	cache_init(&rect_cache, RECT_VERTEX_SHADER, RECT_FRAGMENT_SHADER)

	rect := Rect{}

	rect.program, _ = create_program(rect_cache.vertex_shader, rect_cache.fragment_shader)

	rect.uniform_locations = {
		mp = gl.GetUniformLocation(rect.program, "MP"),
	}

	return rect
}

rect_destroy :: proc(rect: ^Rect) {
	gl.DeleteProgram(rect.program)
}

rect_draw :: proc(rect: ^Rect) {
	gl.UseProgram(rect.program)

	gl.UniformMatrix4fv(rect.uniform_locations.mp, 1, false, linalg.matrix_to_ptr(&rect.mp))

	gl.BindVertexArray(rect_cache.vao)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
	gl.BindVertexArray(0)

	gl.UseProgram(0)
}

@(fini)
rect_cache_destroy :: proc "contextless" () {
	cache_destroy(&rect_cache)
}

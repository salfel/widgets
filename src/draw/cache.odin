package draw

import gl "vendor:OpenGL"

Cache :: struct {
	init:                           bool,
	fragment_shader, vertex_shader: u32,
	vao, vbo:                       u32,
}

cache_init :: proc(cache: ^Cache, vertex_shader: cstring, fragment_shader: cstring) {
	if cache.init {
		return
	}

	VERTICES := []f32{0, 0, 1, 0, 0, 1, 1, 1}

	ok: bool
	cache.vertex_shader, ok = compile_shader(gl.VERTEX_SHADER, vertex_shader)
	assert(ok, "Failed to compile vertex shader")
	cache.fragment_shader, ok = compile_shader(gl.FRAGMENT_SHADER, fragment_shader)
	assert(ok, "Failed to compile fragment shader")

	gl.GenBuffers(1, &cache.vbo)
	gl.GenVertexArrays(1, &cache.vao)
	gl.BindVertexArray(cache.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, cache.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(VERTICES) * size_of(f32), &VERTICES[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	cache.init = true
}

cache_destroy :: proc "contextless" (cache: ^Cache) {
	gl.DeleteBuffers(1, &cache.vbo)
	gl.DeleteVertexArrays(1, &cache.vao)
	gl.DeleteShader(cache.fragment_shader)
	gl.DeleteShader(cache.vertex_shader)
}

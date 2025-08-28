package main

import "state"
import gl "vendor:OpenGL"


BLUR_VERTEX_SHADER :: #load("shaders/blur/vertexShader.glsl", string)
BLUR_FRAGMENT_SHADER :: #load("shaders/blur/fragmentShader.glsl", string)

BlurBuffer :: struct {
	fbo, fbo_texture: [2]u32,
	size:             [2]f32,
	program, vao:     u32,
}

blur_buffer_make :: proc() -> (blur_buffer: BlurBuffer) {
	VERTICES := []f32{-1, -1, 1, -1, -1, 1, 1, 1}

	vertex_shader, _ := compile_shader(gl.VERTEX_SHADER, BLUR_VERTEX_SHADER)
	fragment_shader, _ := compile_shader(gl.FRAGMENT_SHADER, BLUR_FRAGMENT_SHADER)

	blur_buffer.program, _ = create_program(vertex_shader, fragment_shader)

	vbo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenVertexArrays(1, &blur_buffer.vao)
	gl.BindVertexArray(blur_buffer.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(VERTICES) * size_of(f32), &VERTICES[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	blur_buffer_update(&blur_buffer)

	return
}

blur_buffer_bind :: proc(blur_buffer: ^BlurBuffer) {
	blur_buffer_update(blur_buffer)

	gl.BindFramebuffer(gl.FRAMEBUFFER, blur_buffer.fbo[0])
}


blur_buffer_render :: proc(blur_buffer: BlurBuffer) {
	horizontal := true

	gl.BindFramebuffer(gl.FRAMEBUFFER, blur_buffer.fbo[1])

	gl.UseProgram(blur_buffer.program)
	gl.BindVertexArray(blur_buffer.vao)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, blur_buffer.fbo_texture[0])
	gl.Uniform1i(gl.GetUniformLocation(blur_buffer.program, "screenTexture"), 0)
	gl.Uniform1i(gl.GetUniformLocation(blur_buffer.program, "horizontal"), i32(horizontal))

	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.BindVertexArray(0)
	gl.UseProgram(0)

	horizontal = !horizontal

	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

	gl.UseProgram(blur_buffer.program)
	gl.BindVertexArray(blur_buffer.vao)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, blur_buffer.fbo_texture[1])
	gl.Uniform1i(gl.GetUniformLocation(blur_buffer.program, "screenTexture"), 0)
	gl.Uniform1i(gl.GetUniformLocation(blur_buffer.program, "horizontal"), i32(horizontal))

	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.BindVertexArray(0)
	gl.UseProgram(0)
}

blur_buffer_update :: proc(blur_buffer: ^BlurBuffer) {
	if blur_buffer.size == state.app_state.window_size {
		return
	}

	blur_buffer.fbo[0], blur_buffer.fbo_texture[0] = framebuffer_make(
		i32(state.app_state.window_size.x),
		i32(state.app_state.window_size.y),
	)
	blur_buffer.fbo[1], blur_buffer.fbo_texture[1] = framebuffer_make(
		i32(state.app_state.window_size.x),
		i32(state.app_state.window_size.y),
	)

	blur_buffer.size = state.app_state.window_size
}


framebuffer_make :: proc(width, height: i32) -> (fbo: u32, fbo_texture: u32) {
	gl.GenFramebuffers(1, &fbo)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)

	gl.GenTextures(1, &fbo_texture)
	gl.BindTexture(gl.TEXTURE_2D, fbo_texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, fbo_texture, 0)

	return
}

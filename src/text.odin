package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:strings"
import "core:unicode/utf8"
import gl "vendor:OpenGL"
import "vendor:stb/image"
import "vendor:stb/truetype"

TEXT_VERTEX_SHADER :: #load("shaders/text/vertex.glsl", string)
TEXT_FRAGMENT_SHADER :: #load("shaders/text/fragment.glsl", string)

Text :: struct {
	program, vao, texture: u32,
	size, position:        [2]i32,
	mp:                    matrix[4, 4]f32,
}

text_make :: proc(bitmap: []u8, size, position: [2]i32, allocator := context.allocator) -> (text: Text, ok := true) {
	VERTICES := []f32{0, 0, 1, 0, 0, 1, 1, 1}

	vertex_shader := compile_shader(gl.VERTEX_SHADER, TEXT_VERTEX_SHADER) or_return
	fragment_shader := compile_shader(gl.FRAGMENT_SHADER, TEXT_FRAGMENT_SHADER) or_return

	text.program = create_program(vertex_shader, fragment_shader) or_return

	vbo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenVertexArrays(1, &text.vao)
	gl.BindVertexArray(text.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(VERTICES) * size_of(f32), &VERTICES[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	text.texture = text_generate_texture(bitmap, size)
	text.position = position
	text.size = size

	return
}

text_generate_texture :: proc(bitmap: []u8, size: [2]i32, allocator := context.allocator) -> (texture: u32) {
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, size.x, size.y, 0, gl.RED, gl.UNSIGNED_BYTE, raw_data(bitmap))

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

	return
}

text_draw :: proc(text: ^Text) {
	gl.UseProgram(text.program)
	gl.BindVertexArray(text.vao)

	text.mp = text_calculate_mp(text.size, text.position)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, text.texture)

	gl.UniformMatrix4fv(gl.GetUniformLocation(text.program, "MP"), 1, false, linalg.matrix_to_ptr(&text.mp))
	gl.Uniform1i(gl.GetUniformLocation(text.program, "tex"), 0)

	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.BindVertexArray(0)
	gl.UseProgram(0)
}


text_calculate_mp :: proc(size, position: [2]i32) -> (mp: matrix[4, 4]f32) {
	scale := linalg.matrix4_scale_f32({f32(size.x), f32(size.y), 1})
	translation := linalg.matrix4_translate_f32({f32(position.x), f32(position.y), 0})
	projection := linalg.matrix_ortho3d_f32(0, app_state.window_size.x, app_state.window_size.y, 0, 0, 1)

	mp = projection * translation * scale

	return
}

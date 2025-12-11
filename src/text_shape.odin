package main

import "core:math/linalg"
import gl "vendor:OpenGL"

text_cache: Cache

TEXT_VERTEX_SHADER :: #load("shaders/text/vertex.glsl", cstring)
TEXT_FRAGMENT_SHADER :: #load("shaders/text/fragment.glsl", cstring)

Text :: struct {
	content, font:     string,
	color:             [4]f32,
	font_size:         f32,
	pref_size:         [2]i32,
	min_width:         i32,
	mp:                matrix[4, 4]f32,

	// opengl
	program, texture:  u32,
	uniform_locations: struct {
		mp, tex, color: i32,
	},
}

text_make :: proc(content, font: string, font_size: f32, color: [4]f32) -> Text {
	text := Text {
		content   = content,
		font      = font,
		font_size = font_size,
		color     = color,
	}

	text_generate_texture(&text)

	cache_init(&text_cache, TEXT_VERTEX_SHADER, TEXT_FRAGMENT_SHADER)
	text.program, _ = create_program(text_cache.vertex_shader, text_cache.fragment_shader)
	text.uniform_locations = {
		mp    = gl.GetUniformLocation(text.program, "MP"),
		tex   = gl.GetUniformLocation(text.program, "tex"),
		color = gl.GetUniformLocation(text.program, "color"),
	}

	return text
}

text_destroy :: proc(text: ^Text) {
	gl.DeleteTextures(1, &text.texture)
	gl.DeleteProgram(text.program)
}

text_draw :: proc(text: ^Text) {
	gl.UseProgram(text.program)
	gl.BindVertexArray(text_cache.vao)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, text.texture)

	gl.UniformMatrix4fv(text.uniform_locations.mp, 1, false, linalg.matrix_to_ptr(&text.mp))
	gl.Uniform1i(text.uniform_locations.tex, 0)
	gl.Uniform4fv(text.uniform_locations.color, 1, linalg.vector_to_ptr(&text.color))

	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.BindVertexArray(0)
	gl.UseProgram(0)
}

text_set_width :: proc(text: ^Text, width: i32) {
	text_generate_texture(text, width)
}

text_set_content :: proc(text: ^Text, content: string) {
	text.content = content

	text_generate_texture(text)
}

text_generate_texture :: proc(text: ^Text, width: i32 = -1, allocator := context.allocator) -> (ok: bool = true) {
	bitmap: []u8
	stride: i32
	bitmap, text.pref_size, stride, text.min_width = font_bitmap_make(
		text.content,
		text.font,
		f64(text.font_size),
		width,
		allocator,
	) or_return
	defer delete(bitmap)

	gl.GenTextures(1, &text.texture)
	gl.BindTexture(gl.TEXTURE_2D, text.texture)
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.R8,
		text.pref_size.x,
		text.pref_size.y,
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		raw_data(bitmap),
	)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_A, gl.RED)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_R, gl.ZERO)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_G, gl.ZERO)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_B, gl.ZERO)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

	return
}

@(fini)
text_cache_destroy :: proc "contextless" () {
	cache_destroy(&text_cache)
}

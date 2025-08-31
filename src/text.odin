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
	characters:   [dynamic]Character,
	textures:     map[rune]u32,
	program, vao: u32,
	position:     [2]f32,
}

Character :: struct {
	glyph:   Glyph,
	texture: u32,
	mp:      matrix[4, 4]f32,
}


text_make :: proc(
	content: string,
	font: string,
	size: f32,
	position: [2]f32,
	allocator := context.allocator,
) -> (
	text: Text,
	ok := true,
) {
	text.characters = make([dynamic]Character, len(content), allocator)
	text.textures = make(map[rune]u32, len(content), allocator)
	text.position = position

	font_config := font_config_make(font, size, allocator) or_return

	runes := utf8.string_to_runes(content)
	defer delete(runes)
	for char, i in runes {
		next := runes[i + 1] if i < len(runes) - 1 else rune(0)
		glyph := glyph_make(font_config, char, next, allocator)
		text.textures[char] = text_generate_texture(glyph, i32(glyph.width), i32(glyph.height), allocator)

		character := Character {
			glyph   = glyph,
			texture = text.textures[char],
			mp      = calculate_char_mp({glyph.width, glyph.height}, text.position),
		}

		text.characters[i] = character
	}


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

	return
}

text_destroy :: proc(text: ^Text) {
	delete(text.characters)
	delete(text.textures)
}

text_generate_texture :: proc(glyph: Glyph, width, height: i32, allocator := context.allocator) -> (texture: u32) {
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RED,
		i32(width),
		i32(height),
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		raw_data(glyph.bitmap[:]),
	)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

	return
}

text_draw :: proc(text: ^Text) {
	gl.UseProgram(text.program)
	gl.BindVertexArray(text.vao)

	x := text.position.x

	for &character in text.characters {
		character.mp = calculate_char_mp(
			{character.glyph.width, character.glyph.height},
			{
				x + f32(character.glyph.lsb),
				text.position.y + (f32(character.glyph.font_config.ascent) - character.glyph.height),
			},
		)

		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, character.texture)

		gl.UniformMatrix4fv(gl.GetUniformLocation(text.program, "MP"), 1, false, linalg.matrix_to_ptr(&character.mp))
		gl.Uniform1i(gl.GetUniformLocation(text.program, "tex"), 0)

		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

		x += f32(character.glyph.ax) + f32(character.glyph.kern)
	}

	gl.BindVertexArray(0)
	gl.UseProgram(0)
}


calculate_char_mp :: proc(size, position: [2]f32) -> (mp: matrix[4, 4]f32) {
	scale := linalg.matrix4_scale_f32({size.x, size.y, 1})
	translation := linalg.matrix4_translate_f32({position.x, position.y, 0})
	projection := linalg.matrix_ortho3d_f32(0, app_state.window_size.x, app_state.window_size.y, 0, 0, 1)

	mp = projection * translation * scale

	return
}

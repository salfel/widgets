package main

import "core:math"
import "core:math/linalg"
import "css"
import gl "vendor:OpenGL"
import "vendor:stb/truetype"

TEXT_VERTEX_SHADER :: #load("shaders/text/vertex.glsl", string)
TEXT_FRAGMENT_SHADER :: #load("shaders/text/fragment.glsl", string)

Text_Data :: struct {
	program, vao, texture:     u32,
	mp:                        matrix[4, 4]f32,
	mp_location, tex_location: i32,
}

text_make :: proc(
	content, font: string,
	size: f32,
	classes: []string,
	allocator := context.allocator,
) -> (
	widget: ^Widget,
	ok := true,
) #optional_ok {
	styles: map[css.Property]css.Value
	widget, styles = widget_make(classes, allocator)
	widget.type = .Text
	widget.layout.type = .Box

	widget.data = Text_Data{}
	text_data := &widget.data.(Text_Data)

	bitmap, size := font_bitmap_make(content, font, size, allocator) or_return
	defer delete(bitmap)

	widget.layout.width = f32(size.x)
	widget.layout.height = f32(size.y)

	VERTICES := []f32{0, 0, 1, 0, 0, 1, 1, 1}

	vertex_shader := compile_shader(gl.VERTEX_SHADER, TEXT_VERTEX_SHADER) or_return
	fragment_shader := compile_shader(gl.FRAGMENT_SHADER, TEXT_FRAGMENT_SHADER) or_return

	text_data.program = create_program(vertex_shader, fragment_shader) or_return

	vbo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenVertexArrays(1, &text_data.vao)
	gl.BindVertexArray(text_data.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(VERTICES) * size_of(f32), &VERTICES[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	text_data.texture = text_generate_texture(bitmap, size)

	gl.UseProgram(text_data.program)
	text_data.mp_location = gl.GetUniformLocation(text_data.program, "MP")
	text_data.tex_location = gl.GetUniformLocation(text_data.program, "tex")
	gl.UseProgram(0)

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

text_draw :: proc(widget: ^Widget, depth: i32 = 1) {
	text_data, ok := &widget.data.(Text_Data)
	assert(ok, "Expected Text_Data")

	gl.UseProgram(text_data.program)
	gl.BindVertexArray(text_data.vao)

	text_data.mp = calculate_mp(widget.layout)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, text_data.texture)

	gl.UniformMatrix4fv(text_data.mp_location, 1, false, linalg.matrix_to_ptr(&text_data.mp))
	gl.Uniform1i(text_data.tex_location, 0)

	gl.ColorMask(true, true, true, true)
	gl.StencilMask(0x00)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.KEEP)

	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.BindVertexArray(0)
	gl.UseProgram(0)
}

package main

import "core:math"
import "core:math/linalg"
import gl "vendor:OpenGL"
import "vendor:stb/truetype"

TEXT_VERTEX_SHADER :: #load("shaders/text/vertex.glsl", string)
TEXT_FRAGMENT_SHADER :: #load("shaders/text/fragment.glsl", string)

Text_Data :: struct {
	content, font:             string,
	color:                     Color,
	size:                      f32,

	// OpenGL stuff
	program, vao, texture:     u32,
	mp:                        matrix[4, 4]f32,
	mp_location, tex_location: i32,
	color_location:            i32,
}

text_make :: proc(
	content, font: string,
	style: Style,
	allocator := context.allocator,
) -> (
	widget: Widget,
	ok := true,
) #optional_ok {
	widget = widget_make(style, allocator)
	widget.type = .Text
	widget.layout.type = .Box

	widget.data = Text_Data{}
	text_data := &widget.data.(Text_Data)
	text_data.content = content
	text_data.font = font

	text_apply_styles(text_data, style)

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

	size := text_generate_texture(text_data, allocator) or_return
	widget.layout.width = f32(size.x)
	widget.layout.height = f32(size.y)

	gl.UseProgram(text_data.program)
	text_data.mp_location = gl.GetUniformLocation(text_data.program, "MP")
	text_data.tex_location = gl.GetUniformLocation(text_data.program, "tex")
	text_data.color_location = gl.GetUniformLocation(text_data.program, "color")
	gl.UseProgram(0)

	return
}

text_generate_texture :: proc(
	text_data: ^Text_Data,
	allocator := context.allocator,
) -> (
	size: [2]i32,
	ok: bool = true,
) {
	bitmap: []u8
	bitmap, size = font_bitmap_make(text_data.content, text_data.font, text_data.size, allocator) or_return
	defer delete(bitmap)

	gl.GenTextures(1, &text_data.texture)
	gl.BindTexture(gl.TEXTURE_2D, text_data.texture)
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
	gl.Uniform4fv(text_data.color_location, 1, linalg.vector_to_ptr(&text_data.color))

	gl.ColorMask(true, true, true, true)
	gl.StencilMask(0x00)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.KEEP)

	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.BindVertexArray(0)
	gl.UseProgram(0)
}

text_apply_styles :: proc(text_data: ^Text_Data, style: Style) {
	if color, ok := style[.Color]; ok {
		text_data.color, ok = color.(Color)
		assert(ok, "Expected color to be a color vec")
	}

	if size, ok := style[.Font_Size]; ok {
		text_data.size, ok = size.(f32)
		assert(ok, "Expected size to be a number")
	}
}

text_change_content :: proc(id: WidgetId, content: string) -> bool {
	widget := renderer_unsafe_get_widget(id) or_return
	text_data := &widget.data.(Text_Data)
	text_data.content = content
	size := text_generate_texture(text_data) or_return

	widget.layout.width = f32(size.x)
	widget.layout.height = f32(size.y)

	return true
}

package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import gl "vendor:OpenGL"
import "vendor:stb/truetype"

TEXT_VERTEX_SHADER :: #load("shaders/text/vertex.glsl", string)
TEXT_FRAGMENT_SHADER :: #load("shaders/text/fragment.glsl", string)

Text_Data :: struct {
	content, font:                             string,
	style:                                     Text_Style,

	// OpenGL stuff
	program, vao, texture:                     u32,
	mp:                                        matrix[4, 4]f32,
	mp_location, tex_location, color_location: i32,
	uniforms:                                  Text_Uniforms,
}

Text_Uniform :: enum {
	Tex_MP,
	Color,
}
Text_Uniforms :: bit_set[Text_Uniform]

text_make :: proc(content, font: string, allocator := context.allocator) -> (widget: Widget, ok := true) #optional_ok {
	widget.type = .Text
	widget.layout.type = .Box

	widget.data = Text_Data{}
	text_data := &widget.data.(Text_Data)
	text_data.content = content
	text_data.font = font
	text_data.style = DEFAULT_TEXT_STYLE
	text_data.uniforms = Text_Uniforms{.Tex_MP, .Color}

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
	bitmap, size = font_bitmap_make(text_data.content, text_data.font, text_data.style.font_size, allocator) or_return
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

	for uniform in text_data.uniforms {
		switch uniform {
		case .Tex_MP:
			gl.UniformMatrix4fv(text_data.mp_location, 1, false, linalg.matrix_to_ptr(&text_data.mp))
			gl.Uniform1i(text_data.tex_location, 0)
			text_data.uniforms -= {.Tex_MP}
		case .Color:
			gl.Uniform4fv(text_data.color_location, 1, linalg.vector_to_ptr(&text_data.style.color))
			text_data.uniforms -= {.Color}
		}
	}

	gl.ColorMask(true, true, true, true)
	gl.StencilMask(0x00)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.KEEP)

	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.BindVertexArray(0)
	gl.UseProgram(0)
}

text_style_set_color :: proc(renderer: ^Renderer, id: WidgetId, color: Color) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	text_data := (&widget.data.(Text_Data)) or_return
	text_data.style.color = color
	text_data.uniforms += {.Color}

	renderer.dirty = true

	return true
}

text_style_set_font_size :: proc(renderer: ^Renderer, id: WidgetId, font_size: f32) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	text_data := (&widget.data.(Text_Data)) or_return
	text_data.style.font_size = font_size
	size := text_generate_texture(text_data) or_return
	text_data.uniforms += {.Tex_MP}

	widget.layout.width = f32(size.x)
	widget.layout.height = f32(size.y)

	renderer.dirty = true

	return true
}

text_set_content :: proc(renderer: ^Renderer, id: WidgetId, content: string) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	text_data := (&widget.data.(Text_Data)) or_return
	text_data.content = content
	size := text_generate_texture(text_data) or_return
	text_data.uniforms += {.Tex_MP}

	widget.layout.width = f32(size.x)
	widget.layout.height = f32(size.y)

	renderer.dirty = true

	return true
}

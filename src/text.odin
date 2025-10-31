package main

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import gl "vendor:OpenGL"
import "vendor:stb/truetype"

TEXT_VERTEX_SHADER :: #load("shaders/text/vertex.glsl", string)
TEXT_FRAGMENT_SHADER :: #load("shaders/text/fragment.glsl", string)

text_cache: Widget_Cache

Text :: struct {
	// style
	content, font:                             string,
	style:                                     Text_Style,

	// OpenGL stuff
	program, texture:                          u32,
	mp_location, tex_location, color_location: i32,
	mp:                                        matrix[4, 4]f32,
	pending_uniforms:                          Text_Uniforms,
}

Text_Uniform :: enum {
	Tex_MP,
	Color,
}
Text_Uniforms :: bit_set[Text_Uniform]

text_make :: proc(
	content, font: string,
	allocator := context.allocator,
) -> (
	widget: ^Widget,
	ok := true,
) #optional_ok {
	widget = widget_make(allocator)
	widget.type = .Text
	widget.layout.type = .Box
	widget.draw = text_draw
	widget.on_window_resize = text_on_window_resize
	widget.data = Text{}

	text := &widget.data.(Text)
	text.content = content
	text.font = font
	text.style = DEFAULT_TEXT_STYLE
	text.pending_uniforms = Text_Uniforms{.Tex_MP, .Color}

	size := text_generate_texture(text, allocator) or_return
	widget.layout.style.width = f32(size.x)
	widget.layout.style.height = f32(size.y)


	if !text_cache.init {
		text_cache_init() or_return
	}

	text.program = create_program(text_cache.vertex_shader, text_cache.fragment_shader) or_return

	text.mp_location = gl.GetUniformLocation(text.program, "MP")
	text.tex_location = gl.GetUniformLocation(text.program, "tex")
	text.color_location = gl.GetUniformLocation(text.program, "color")

	return
}

text_draw :: proc(widget: ^Widget, depth: i32 = 1) {
	text, ok := (&widget.data.(Text))
	if !ok {
		fmt.println("invalid widget type, expected Text, got:", widget.type)
		return
	}

	gl.UseProgram(text.program)
	gl.BindVertexArray(text_cache.vao)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, text.texture)

	for uniform in text.pending_uniforms {
		switch uniform {
		case .Tex_MP:
			text.mp = calculate_mp(widget.layout)
			gl.UniformMatrix4fv(text.mp_location, 1, false, linalg.matrix_to_ptr(&text.mp))
			gl.Uniform1i(text.tex_location, 0)
			text.pending_uniforms -= {.Tex_MP}
		case .Color:
			gl.Uniform4fv(text.color_location, 1, linalg.vector_to_ptr(&text.style.color))
			text.pending_uniforms -= {.Color}
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

text_generate_texture :: proc(text: ^Text, allocator := context.allocator) -> (size: [2]i32, ok: bool = true) {
	bitmap: []u8
	bitmap, size = font_bitmap_make(text.content, text.font, text.style.font_size, allocator) or_return
	defer delete(bitmap)

	gl.GenTextures(1, &text.texture)
	gl.BindTexture(gl.TEXTURE_2D, text.texture)
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, size.x, size.y, 0, gl.RED, gl.UNSIGNED_BYTE, raw_data(bitmap))

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

	return
}

text_on_window_resize :: proc(widget: ^Widget, size: [2]f32) {
	text, ok := (&widget.data.(Text))
	if !ok {
		fmt.println("invalid widget type, expected Text, got:", widget.type)
		return
	}

	text.mp = calculate_mp(widget.layout)
	text.pending_uniforms += {.Tex_MP}

	renderer.dirty = true

	return
}

text_style_set_color :: proc(renderer: ^Renderer, id: WidgetId, color: Color, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	text, ok := (&widget.data.(Text))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	text.style.color = color
	text.pending_uniforms += {.Color}

	return true
}

text_style_set_font_size :: proc(renderer: ^Renderer, id: WidgetId, font_size: f32, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	text, ok := (&widget.data.(Text))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	text.style.font_size = font_size
	size := text_generate_texture(text) or_return
	text.pending_uniforms += {.Tex_MP}

	widget.layout.style.width = f32(size.x)
	widget.layout.style.height = f32(size.y)

	renderer.dirty = true

	return true
}

text_set_content :: proc(renderer: ^Renderer, id: WidgetId, content: string, loc := #caller_location) -> bool {
	widget := renderer_unsafe_get_widget(renderer, id) or_return
	text, ok := (&widget.data.(Text))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	text.content = content
	size := text_generate_texture(text) or_return
	text.pending_uniforms += {.Tex_MP}

	widget.layout.style.width = f32(size.x)
	widget.layout.style.height = f32(size.y)

	renderer.dirty = true

	return true
}

text_cache_init :: proc() -> bool {
	VERTICES := []f32{0, 0, 1, 0, 0, 1, 1, 1}

	text_cache.vertex_shader = compile_shader(gl.VERTEX_SHADER, TEXT_VERTEX_SHADER) or_return
	text_cache.fragment_shader = compile_shader(gl.FRAGMENT_SHADER, TEXT_FRAGMENT_SHADER) or_return

	gl.GenBuffers(1, &text_cache.vbo)
	gl.GenVertexArrays(1, &text_cache.vao)
	gl.BindVertexArray(text_cache.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, text_cache.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(VERTICES) * size_of(f32), &VERTICES[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	text_cache.init = true

	return true
}

@(fini)
text_cache_destroy :: proc "contextless" () {
	widget_cache_destroy(&text_cache)
}

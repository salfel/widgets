package main

import "core:math/linalg"
import gl "vendor:OpenGL"

text_cache: Cache

TEXT_VERTEX_SHADER :: #load("shaders/text/vertex.glsl", cstring)
TEXT_FRAGMENT_SHADER :: #load("shaders/text/fragment.glsl", cstring)

Text :: struct {
	// internal
	style_id:           Text_Style_Id,
	content, font_name: string,
	font:               Font,

	// external
	mp:                 matrix[4, 4]f32,
	layout:             Layout,

	// opengl
	program, texture:   u32,
	uniform_locations:  [Text_Uniform]i32,
	pending_uniforms:   bit_set[Text_Uniform],
}

Text_Uniform :: enum {
	MP,
	Tex,
	Color,
	Background_Color,
}

text_init :: proc(text: ^Text, content, font: string, style: Text_Style_Id = 0) {
	text.content = content
	text.font_name = font

	text.style_id = style
	style_subscribe(style, text_changed_style, text)

	style, ok := style_get(style)
	assert(ok, "style not found")

	text.font = font_make(content, font, f64(style.font_size))

	text_changed_style(text, true)

	cache_init(&text_cache, TEXT_VERTEX_SHADER, TEXT_FRAGMENT_SHADER)
	text.program, _ = create_program(text_cache.vertex_shader, text_cache.fragment_shader)
	text.uniform_locations = {
		.MP               = gl.GetUniformLocation(text.program, "MP"),
		.Tex              = gl.GetUniformLocation(text.program, "tex"),
		.Color            = gl.GetUniformLocation(text.program, "color"),
		.Background_Color = gl.GetUniformLocation(text.program, "background_color"),
	}
	text.pending_uniforms = {.MP, .Tex, .Color, .Background_Color}
}

text_destroy :: proc(text: ^Text) {
	font_destroy(&text.font)

	gl.DeleteTextures(1, &text.texture)
	gl.DeleteProgram(text.program)
}

text_draw :: proc(text: ^Text) {
	gl.UseProgram(text.program)
	gl.BindVertexArray(text_cache.vao)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, text.texture)

	style, ok := style_get(text.style_id)
	assert(ok, "style not found")

	for uniform in text.pending_uniforms {
		switch uniform {
		case .MP:
			gl.UniformMatrix4fv(text.uniform_locations[.MP], 1, false, linalg.matrix_to_ptr(&text.mp))
		case .Tex:
			gl.Uniform1i(text.uniform_locations[.Tex], 0)
		case .Color:
			gl.Uniform4fv(text.uniform_locations[.Color], 1, linalg.vector_to_ptr(&style.color))
		case .Background_Color:
			gl.Uniform4fv(text.uniform_locations[.Background_Color], 1, linalg.vector_to_ptr(&style.background_color))
		}
		text.pending_uniforms = {}
	}

	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.BindVertexArray(0)
	gl.UseProgram(0)
}

text_set_width :: proc(text: ^Text, width: i32) {
	font_set_width(&text.font, width)

	text_update_layout(text)
	text_generate_texture(text)
}

text_set_content :: proc(text: ^Text, content: string) {
	text.content = content

	font_set_content(&text.font, content)
	text_update_layout(text)
	text_generate_texture(text)
}

text_set_wrap :: proc(text: ^Text, wrap: Wrap) {
	font_set_wrap(&text.font, wrap)

	text_update_layout(text)
	text_generate_texture(text)
}

text_changed_style :: proc(data: rawptr, initial: bool) {
	text := cast(^Text)data
	style, ok := style_get(text.style_id)
	assert(ok, "style not found")

	changed_properties := DEFAULT_TEXT_STYLE.changed_properties if initial else style.changed_properties

	for property in changed_properties {
		switch property {
		case .Font_Size:
			ok := font_set_size(&text.font, f64(style.font_size))
			if ok {
				text_update_layout(text)
				text_generate_texture(text)
				text.pending_uniforms += {.Tex}
			}
		// TODO: set renderer dirty
		case .Color:
			text.pending_uniforms += {.Color}
		case .Background_Color:
			text.pending_uniforms += {.Background_Color}
		case .Wrap:
			ok := font_set_wrap(&text.font, style.wrap)
			if ok {
				text_update_layout(text)
				text_generate_texture(text)
				text.pending_uniforms += {.Tex}
			}
		}
	}
}

text_update_layout :: proc(text: ^Text) {
	text.layout.style.size.x = layout_constraint_make(f32(text.font.min_width), f32(text.font.size.x))
	text.layout.style.size.y = layout_constraint_make(f32(text.font.size.y))
}

text_generate_texture :: proc(text: ^Text, allocator := context.allocator) -> (ok: bool = true) {
	bitmap := font_get_bitmap(&text.font)

	gl.GenTextures(1, &text.texture)
	gl.BindTexture(gl.TEXTURE_2D, text.texture)
	gl.PixelStorei(gl.UNPACK_ROW_LENGTH, text.font.stride)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.R8,
		i32(text.font.ink_rect.size.x),
		i32(text.font.ink_rect.size.y),
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		bitmap,
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

text_recalculate_mp :: proc(text: ^Text, app_context: ^App_Context) {
	copy := text.layout
	copy.position += convert_vec(text.font.ink_rect.position, f32)
	copy.size = convert_vec(text.font.ink_rect.size, f32)
	text.mp = calculate_mp(copy, app_context)
	text.pending_uniforms += {.MP}
}

@(fini)
text_cache_destroy :: proc "contextless" () {
	cache_destroy(&text_cache)
}

package main

import "core:math/linalg"
import gl "vendor:OpenGL"

RECT_VERTEX_SHADER :: #load("shaders/rect/vertex.glsl", cstring)
RECT_FRAGMENT_SHADER :: #load("shaders/rect/fragment.glsl", cstring)

rect_cache: Cache

Rect :: struct {
	// internal
	mp:                matrix[4, 4]f32,
	layout:            Layout,
	style_id:          Rect_Style_Id,

	// opengl
	program:           u32,
	uniform_locations: [Rect_Uniform]i32,
	pending_uniforms:  bit_set[Rect_Uniform],
}

Rect_Uniform :: enum {
	MP,
	Background_Color,
}

rect_init :: proc(rect: ^Rect, style_id: Rect_Style_Id) {
	cache_init(&rect_cache, RECT_VERTEX_SHADER, RECT_FRAGMENT_SHADER)

	rect.style_id = style_id
	style_subscribe(style_id, rect_style_changed, rect)

	rect_style_changed(rect, true)

	rect.program, _ = create_program(rect_cache.vertex_shader, rect_cache.fragment_shader)

	rect.uniform_locations = {
		.MP               = gl.GetUniformLocation(rect.program, "MP"),
		.Background_Color = gl.GetUniformLocation(rect.program, "color"),
	}
	rect.pending_uniforms = {.MP, .Background_Color}
}

rect_destroy :: proc(rect: ^Rect) {
	gl.DeleteProgram(rect.program)
	layout_destroy(&rect.layout)
}

rect_draw :: proc(rect: ^Rect) {
	gl.UseProgram(rect.program)

	for uniform in rect.pending_uniforms {
		switch uniform {
		case .MP:
			gl.UniformMatrix4fv(rect.uniform_locations[.MP], 1, false, linalg.matrix_to_ptr(&rect.mp))
		case .Background_Color:
			rect_style, ok := style_get(rect.style_id)
			assert(ok, "style not found")

			gl.Uniform4fv(
				rect.uniform_locations[.Background_Color],
				1,
				linalg.vector_to_ptr(&rect_style.background_color),
			)
		}
		rect.pending_uniforms = {}
	}

	gl.BindVertexArray(rect_cache.vao)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
	gl.BindVertexArray(0)

	gl.UseProgram(0)
}

rect_recalculate_mp :: proc(rect: ^Rect, app_context: ^App_Context) {
	rect.mp = calculate_mp(rect.layout, app_context)
	rect.pending_uniforms += {.MP}
}

rect_style_changed :: proc(data: rawptr, initial: bool) {
	rect := cast(^Rect)data

	style, ok := style_get(rect.style_id)
	assert(ok, "style not found")

	changed_properties := DEFAULT_RECT_STYLE.changed_properties if initial else style.changed_properties

	for property in changed_properties {
		switch property {
		case .Width:
			rect.layout.style.size.x = layout_constraint_make(style.width)
		case .Height:
			rect.layout.style.size.y = layout_constraint_make(style.height)
		case .Background_Color:
			rect.pending_uniforms += {.Background_Color}
		}
	}
}

@(fini)
rect_cache_destroy :: proc "contextless" () {
	cache_destroy(&rect_cache)
}

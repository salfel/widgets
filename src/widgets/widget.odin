package widgets

import "../css"
import "../state"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:testing"
import "core:time"
import gl "vendor:OpenGL"

VERTEX_SHADER :: #load("shaders/vertex.glsl", string)
FRAGMENT_SHADER :: #load("shaders/fragment.glsl", string)


Widget :: struct {
	// render
	color:                        [4]f32,
	mp:                           matrix[4, 4]f32,

	// layout
	children:                     [dynamic]Widget,
	parent:                       ^Widget,
	layout:                       Layout,

	// OpenGL stuff
	program, vao:                 u32,
	mvp_location, color_location: i32,
}

widget_make :: proc(classes: []string) -> (widget: Widget, ok: bool) #optional_ok {
	styles: map[css.Property]css.Value
	for selector in state.app_state.css.selectors {
		if selector.type != .Class {continue}

		for class in classes {
			if selector.name == class {
				for property, value in selector.declarations {
					styles[property] = value
				}
			}
		}
	}
	if height, ok := styles[.Height]; ok {
		widget.layout.result.size.y = f32(height.(u32))
	}

	if width, ok := styles[.Width]; ok {
		widget.layout.preferred = f32(width.(u32))
	}

	if color, ok := styles[.Color]; ok {
		col := color.([3]f32)
		widget.color = [4]f32{col[0], col[1], col[2], 1}
	}

	widget.layout.max = math.INF_F32

	VERTICES := []f32{0, 0, 1, 0, 0, 1, 1, 1}

	vertex_shader := compile_shader(gl.VERTEX_SHADER, VERTEX_SHADER) or_return
	fragment_shader := compile_shader(gl.FRAGMENT_SHADER, FRAGMENT_SHADER) or_return

	widget.program = create_program(vertex_shader, fragment_shader) or_return

	vbo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenVertexArrays(1, &widget.vao)
	gl.BindVertexArray(widget.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(VERTICES) * size_of(f32), &VERTICES[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	gl.UseProgram(widget.program)
	widget.mvp_location = gl.GetUniformLocation(widget.program, "MVP")
	widget.color_location = gl.GetUniformLocation(widget.program, "color")
	gl.UseProgram(0)

	return
}

widget_draw :: proc(widget: ^Widget) {
	gl.UseProgram(widget.program)

	calculate_mp(widget)

	gl.UniformMatrix4fv(widget.mvp_location, 1, false, linalg.matrix_to_ptr(&widget.mp))
	gl.Uniform4fv(widget.color_location, 1, linalg.vector_to_ptr(&widget.color))

	gl.BindVertexArray(widget.vao)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	e := gl.GetError()
	if e != gl.NO_ERROR {
		fmt.println("Error while drawing widget", e)
	}

	gl.UseProgram(0)

	if widget.layout.result.clip {
		gl.Enable(gl.SCISSOR_TEST)
		gl.Scissor(
			i32(widget.layout.result.position.x),
			i32(state.app_state.window.height - widget.layout.result.position.y - widget.layout.result.size.y),
			i32(widget.layout.result.size.x),
			i32(widget.layout.result.size.y),
		)
	}

	for &child in widget.children {
		widget_draw(&child)
	}

	if widget.layout.result.clip {
		gl.Disable(gl.SCISSOR_TEST)
	}
}

widget_append_child :: proc(widget: ^Widget, child: Widget) {
	append(&widget.children, child)
	widget.children[len(widget.children) - 1].parent = widget
	append(&widget.layout.children, &widget.children[len(widget.children) - 1].layout)
}

calculate_mp :: proc(widget: ^Widget) {
	size := widget.layout.result.size
	position := widget.layout.result.position

	scale := linalg.matrix4_scale_f32({size.x, size.y, 1})
	translation := linalg.matrix4_translate_f32({position.x, position.y, 0})
	projection := linalg.matrix_ortho3d_f32(0, state.app_state.window.width, state.app_state.window.height, 0, 0, 1)

	widget.mp = projection * translation * scale
}

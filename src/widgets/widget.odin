package widgets

import "../state"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:testing"
import "core:time"
import gl "vendor:OpenGL"

VERTEX_SHADER :: #load("shaders/vertex.glsl")
FRAGMENT_SHADER :: #load("shaders/fragment.glsl")


Widget :: struct {
	size:                         [2]f32,
	position:                     [2]f32,
	color:                        [4]f32,
	mp:                           matrix[4, 4]f32,

	// OpenGL stuff
	program, vao:                 u32,
	mvp_location, color_location: i32,
}

Widget_Error :: enum {
	None,
	Shader_Compilation_Failed,
	Program_Creation_Failed,
}

widget_make :: proc(size, position: [2]f32, color: [4]f32) -> (widget: Widget, err: Widget_Error) {
	widget.size = size
	widget.position = position
	widget.color = color

	VERTICES := []f32{0, 0, 1, 0, 0, 1, 1, 1}

	vertex_shader := compile_shader(gl.VERTEX_SHADER, string(VERTEX_SHADER)) or_return
	fragment_shader := compile_shader(gl.FRAGMENT_SHADER, string(FRAGMENT_SHADER)) or_return

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
}

calculate_mp :: proc(widget: ^Widget) {
	scale := linalg.matrix4_scale_f32({widget.size.x, widget.size.y, 1})
	translation := linalg.matrix4_translate_f32({widget.position.x, widget.position.y, 0})
	projection := linalg.matrix_ortho3d_f32(0, state.app_state.window.width, state.app_state.window.height, 0, 0, 1)

	widget.mp = projection * translation * scale
}

compile_shader :: proc(type: u32, source: string) -> (u32, Widget_Error) {
	source := strings.clone_to_cstring(source)
	defer delete(source)

	shader := gl.CreateShader(type)
	gl.ShaderSource(shader, 1, &source, nil)
	gl.CompileShader(shader)

	success: [^]i32 = make([^]i32, 1)
	defer free(success)

	gl.GetShaderiv(shader, gl.COMPILE_STATUS, success)
	if success[0] == 0 {
		buffer: [^]u8 = make([^]u8, 512)
		defer free(buffer)

		gl.GetShaderInfoLog(shader, 512, nil, buffer)

		err := strings.clone_from_ptr(buffer, 512)
		defer delete(err)

		fmt.println("Shader compilation failed:", err)
		return 0, .Shader_Compilation_Failed
	}

	return shader, .None
}

create_program :: proc(vertex_shader: u32, fragmemt_shader: u32) -> (u32, Widget_Error) {
	program := gl.CreateProgram()

	gl.AttachShader(program, vertex_shader)
	gl.AttachShader(program, fragmemt_shader)
	gl.LinkProgram(program)

	defer {
		gl.DetachShader(program, vertex_shader)
		gl.DetachShader(program, fragmemt_shader)
		gl.DeleteShader(vertex_shader)
		gl.DeleteShader(fragmemt_shader)
	}

	success: [^]i32 = make([^]i32, 1)
	defer free(success)

	gl.GetProgramiv(program, gl.LINK_STATUS, success)
	if success[0] == 0 {
		buffer: [^]u8 = make([^]u8, 512)
		defer free(buffer)

		gl.GetProgramInfoLog(program, 512, nil, buffer)
		fmt.println("Program linking failed:", strings.clone_from_ptr(buffer, 512))
		return 0, .Program_Creation_Failed
	}

	return program, .None
}

@(test)
test_program_creation :: proc(t: ^testing.T) {
	window_handle, ok := window_make(800, 600, "widgets")
	testing.expect(t, ok)
	defer window_destroy(window_handle)

	vertex_shader, success := compile_shader(gl.VERTEX_SHADER, string(VERTEX_SHADER))
	testing.expect(t, success == .None)

	fragment_shader: u32
	fragment_shader, success = compile_shader(gl.FRAGMENT_SHADER, string(FRAGMENT_SHADER))
	testing.expect(t, success == .None)

	program: u32
	program, success = create_program(vertex_shader, fragment_shader)
	testing.expect(t, success == .None)
	defer gl.DeleteProgram(program)
}

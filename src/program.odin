package main

import "core:fmt"
import "core:strings"
import "core:testing"
import gl "vendor:OpenGL"


compile_shader :: proc(type: u32, source: cstring, allocator := context.allocator) -> (u32, bool) {
	source := source

	shader := gl.CreateShader(type)
	gl.ShaderSource(shader, 1, &source, nil)
	gl.CompileShader(shader)

	success: [^]i32 = make([^]i32, 1, allocator)
	defer free(success)

	gl.GetShaderiv(shader, gl.COMPILE_STATUS, success)
	if success[0] == 0 {
		buffer: [^]u8 = make([^]u8, 512, allocator)
		defer free(buffer)

		gl.GetShaderInfoLog(shader, 512, nil, buffer)
		err := strings.clone_from_ptr(buffer, 512, allocator)
		defer delete(err)

		fmt.println("Shader compilation failed:", err)
		return 0, false
	}

	return shader, true
}

create_program :: proc(vertex_shader: u32, fragmemt_shader: u32, allocator := context.allocator) -> (u32, bool) {
	program := gl.CreateProgram()

	gl.AttachShader(program, vertex_shader)
	gl.AttachShader(program, fragmemt_shader)
	gl.LinkProgram(program)

	defer {
		gl.DetachShader(program, vertex_shader)
		gl.DetachShader(program, fragmemt_shader)
	}

	success: [^]i32 = make([^]i32, 1, allocator)
	defer free(success)

	gl.GetProgramiv(program, gl.LINK_STATUS, success)
	if success[0] == 0 {
		buffer: [^]u8 = make([^]u8, 512, allocator)
		defer free(buffer)

		gl.GetProgramInfoLog(program, 512, nil, buffer)
		err := strings.clone_from_ptr(buffer, 512, allocator)
		defer delete(err)

		fmt.println("Program linking failed:", err)

		return 0, false
	}

	return program, true
}

@(test)
test_program_creation :: proc(t: ^testing.T) {
	app_context: App_Context
	app_context_init(&app_context, "widgets", "widgets")
	defer app_context_destroy(&app_context)

	vertex_shader, success := compile_shader(gl.VERTEX_SHADER, VERTEX_SHADER)
	testing.expect(t, success)

	fragment_shader: u32
	fragment_shader, success = compile_shader(gl.FRAGMENT_SHADER, FRAGMENT_SHADER)
	testing.expect(t, success)

	program: u32
	program, success = create_program(vertex_shader, fragment_shader)
	testing.expect(t, success)
	defer gl.DeleteProgram(program)
}

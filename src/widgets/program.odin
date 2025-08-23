package widgets

import "core:strings"
import gl "vendor:OpenGL"
import "core:fmt"
import "core:testing"


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

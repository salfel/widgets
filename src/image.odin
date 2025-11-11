package main

import "core:bytes"
import "core:fmt"
import "core:image"
import "core:math/linalg"
import gl "vendor:OpenGL"

// don't remove, needed for registering
import "core:image/jpeg"
import "core:image/png"

IMAGE_VERTEX_SHADER :: #load("shaders/image/vertex.glsl", string)
IMAGE_FRAGMENT_SHADER :: #load("shaders/image/fragment.glsl", string)

Image :: struct {
	style:             Image_Style,
	image:             ^image.Image,

	// OpenGL stuff
	program, texture:  u32,
	uniform_locations: struct {
		mp, tex, opacity: i32,
	},
	mp:                matrix[4, 4]f32,
	pending_uniforms:  Image_Uniforms,
}

Image_Uniform :: enum {
	MP,
	Tex,
	Opacity,
}
Image_Uniforms :: bit_set[Image_Uniform]

image_cache: Widget_Cache

image_make :: proc(path: string, allocator := context.allocator) -> (widget: ^Widget, ok := true) #optional_ok {
	widget = widget_make(allocator)
	widget.type = .Image
	widget.layout.type = .Box
	widget.allow_children = false
	widget.draw = image_draw
	widget.recalculate_mp = image_recalculate_mp
	widget.destroy = image_destroy
	widget.data = Image{}

	image_data := &widget.data.(Image)
	image_data.style = DEFAULT_IMAGE_STYLE
	image_data.pending_uniforms = Image_Uniforms{.MP, .Tex, .Opacity}

	err: image.Error
	image_data.image, err = image.load_from_file(path)
	if err != nil {
		fmt.println("couldn't load image from file", err, ", path:", path)
		return
	}

	if !image_cache.init {
		image_cache_init() or_return
	}

	widget.layout.style.size.x = axis_make(f32(image_data.image.width))
	widget.layout.style.size.y = axis_make(f32(image_data.image.height))
	image_data.texture = image_generate_texture(image_data.image, allocator)

	image_data.program = create_program(image_cache.vertex_shader, image_cache.fragment_shader) or_return

	image_data.uniform_locations.mp = gl.GetUniformLocation(image_data.program, "MP")
	image_data.uniform_locations.tex = gl.GetUniformLocation(image_data.program, "tex")
	image_data.uniform_locations.opacity = gl.GetUniformLocation(image_data.program, "opacity")

	return
}

image_destroy :: proc(widget: ^Widget) {
	image_data, ok := (&widget.data.(Image))
	if !ok {
		fmt.println("invalid widget type, expected Image, got:", widget.type)
		return
	}

	gl.DeleteTextures(1, &image_data.texture)
	gl.DeleteProgram(image_data.program)

	image.destroy(image_data.image)
}

image_draw :: proc(widget: ^Widget, app_context: ^App_Context, depth: i32 = 1) {
	image, ok := (&widget.data.(Image))
	if !ok {
		fmt.println("invalid widget type, expected Text, got:", widget.type)
		return
	}

	gl.UseProgram(image.program)
	gl.BindVertexArray(image_cache.vao)

	for uniform in image.pending_uniforms {
		switch uniform {
		case .MP:
			image.mp = calculate_mp(widget.layout, app_context)
			gl.UniformMatrix4fv(image.uniform_locations.mp, 1, false, linalg.matrix_to_ptr(&image.mp))
			image.pending_uniforms -= {.MP}
		case .Tex:
			image.texture = image_generate_texture(image.image)

			gl.Uniform1i(image.uniform_locations.tex, 0)
			image.pending_uniforms -= {.Tex}
		case .Opacity:
			gl.Uniform1f(image.uniform_locations.opacity, image.style.opacity)
			image.pending_uniforms -= {.Opacity}
		}
	}

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, image.texture)

	gl.ColorMask(true, true, true, true)
	gl.StencilMask(0x00)
	gl.StencilFunc(gl.EQUAL, depth - 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.KEEP)

	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.BindVertexArray(0)
	gl.UseProgram(0)
}

image_recalculate_mp :: proc(widget: ^Widget, app_context: ^App_Context) {
	image_data, ok := (&widget.data.(Image))
	if !ok {
		fmt.println("invalid widget type, expected Image, got:", widget.type)
		return
	}

	image_data.pending_uniforms += {.MP}

	app_context.renderer.dirty = true

	return
}

image_generate_texture :: proc(img: ^image.Image, allocator := context.allocator) -> (texture: u32) {
	bitmap := bytes.buffer_to_bytes(&img.pixels)

	format: i32 = gl.RGB

	#partial switch img.which {
	case .PNG:
		metadata := img.metadata.(^image.PNG_Info)
		format = gl.RGBA if .Alpha in metadata.header.color_type else gl.RGB
	}

	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		format,
		i32(img.width),
		i32(img.height),
		0,
		u32(format),
		gl.UNSIGNED_BYTE,
		raw_data(bitmap),
	)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

	return
}


image_style_set_width :: proc(widget: ^Widget, width: f32, renderer: ^Renderer, loc := #caller_location) -> bool {
	image, ok := (&widget.data.(Image))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	widget.layout.style.size.x = axis_make(width)
	image.pending_uniforms += {.MP, .Tex}

	renderer.dirty = true

	return true
}

image_style_set_height :: proc(widget: ^Widget, height: f32, renderer: ^Renderer, loc := #caller_location) -> bool {
	image, ok := (&widget.data.(Image))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	widget.layout.style.size.y = axis_make(height)
	image.pending_uniforms += {.MP, .Tex}

	renderer.dirty = true

	return true
}

image_style_set_margin :: proc(widget: ^Widget, margin: Sides, renderer: ^Renderer, loc := #caller_location) -> bool {
	image, ok := (&widget.data.(Image))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	widget.layout.style.margin = margin
	image.pending_uniforms += {.MP}

	renderer.dirty = true

	return true
}

image_style_set_opacity :: proc(widget: ^Widget, opacity: f32, renderer: ^Renderer, loc := #caller_location) -> bool {
	image, ok := (&widget.data.(Image))
	if !ok {
		fmt.println("invalid widget type", loc)
		return false
	}
	image.style.opacity = opacity
	image.pending_uniforms += {.Opacity}

	renderer.dirty = true

	return true
}


image_cache_init :: proc() -> bool {
	VERTICES := []f32{0, 0, 1, 0, 0, 1, 1, 1}

	image_cache.vertex_shader = compile_shader(gl.VERTEX_SHADER, IMAGE_VERTEX_SHADER) or_return
	image_cache.fragment_shader = compile_shader(gl.FRAGMENT_SHADER, IMAGE_FRAGMENT_SHADER) or_return

	gl.GenBuffers(1, &image_cache.vbo)
	gl.GenVertexArrays(1, &image_cache.vao)
	gl.BindVertexArray(image_cache.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, image_cache.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(VERTICES) * size_of(f32), &VERTICES[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	image_cache.init = true

	return true
}

@(fini)
image_cache_destroy :: proc "contextless" () {
	widget_cache_destroy(&image_cache)
}

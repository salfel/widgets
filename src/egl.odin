package main

import "core:fmt"
import wl "lib:wayland"
import gl "vendor:OpenGL"
import "vendor:egl"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

Egl_State :: struct {
	window:  ^wl.egl_window,
	display: egl.Display,
	surface: egl.Surface,
	ctx:     egl.Context,
}


egl_init :: proc(window_context: ^Window_Context) {
	major, minor: i32
	egl.BindAPI(egl.OPENGL_API)
	config_attribs := []i32 {
		egl.SURFACE_TYPE,
		egl.WINDOW_BIT,
		egl.RENDERABLE_TYPE,
		egl.OPENGL_BIT,
		egl.RED_SIZE,
		8,
		egl.GREEN_SIZE,
		8,
		egl.BLUE_SIZE,
		8,
		egl.DEPTH_SIZE,
		24,
		egl.STENCIL_SIZE,
		8,
		egl.NONE,
	}

	window_context.egl.display = egl.GetDisplay(cast(egl.NativeDisplayType)window_context.wl.display)
	if window_context.egl.display == nil {
		fmt.println("Failed to get EGL display")
		return
	}

	egl.Initialize(window_context.egl.display, &major, &minor)

	config: egl.Config
	num_config: i32

	egl.ChooseConfig(window_context.egl.display, raw_data(config_attribs), &config, 1, &num_config)
	window_context.egl.ctx = egl.CreateContext(window_context.egl.display, config, nil, nil)
	window_context.egl.window = wl.egl_window_create(window_context.wl.surface, 1280, 720)
	window_context.egl.surface = egl.CreateWindowSurface(
		window_context.egl.display,
		config,
		cast(egl.NativeWindowType)window_context.egl.window,
		nil,
	)
	wl.surface_commit(window_context.wl.surface)
	egl.MakeCurrent(
		window_context.egl.display,
		window_context.egl.surface,
		window_context.egl.surface,
		window_context.egl.ctx,
	)
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, egl.gl_set_proc_address)

	egl.SwapInterval(window_context.egl.display, 1)
}

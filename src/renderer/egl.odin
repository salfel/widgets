package renderer

import wl "../../lib/wayland"
import "core:fmt"
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


egl_init :: proc() {
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

	g_Renderer.egl_state.display = egl.GetDisplay(cast(egl.NativeDisplayType)g_Renderer.wl_state.display)
	if g_Renderer.egl_state.display == nil {
		fmt.println("Failed to get EGL display")
		return
	}

	egl.Initialize(g_Renderer.egl_state.display, &major, &minor)
	fmt.println("EGL Major, EGL Minor", major, minor)

	config: egl.Config
	num_config: i32

	egl.ChooseConfig(g_Renderer.egl_state.display, raw_data(config_attribs), &config, 1, &num_config)
	g_Renderer.egl_state.ctx = egl.CreateContext(g_Renderer.egl_state.display, config, nil, nil)
	g_Renderer.egl_state.window = wl.egl_window_create(g_Renderer.wl_state.surface, 1280, 720)
	g_Renderer.egl_state.surface = egl.CreateWindowSurface(
		g_Renderer.egl_state.display,
		config,
		cast(egl.NativeWindowType)g_Renderer.egl_state.window,
		nil,
	)
	wl.surface_commit(g_Renderer.wl_state.surface)
	egl.MakeCurrent(
		g_Renderer.egl_state.display,
		g_Renderer.egl_state.surface,
		g_Renderer.egl_state.surface,
		g_Renderer.egl_state.ctx,
	)
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, egl.gl_set_proc_address)

	egl.SwapInterval(g_Renderer.egl_state.display, 1)
}

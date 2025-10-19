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


egl_init :: proc(egl_state: ^Egl_State, wl_state: ^Wayland_State) {
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

	egl_state.display = egl.GetDisplay(cast(egl.NativeDisplayType)wl_state.display)
	if egl_state.display == nil {
		fmt.println("Failed to get EGL display")
		return
	}

	egl.Initialize(egl_state.display, &major, &minor)
	fmt.println("EGL Major, EGL Minor", major, minor)

	config: egl.Config
	num_config: i32

	egl.ChooseConfig(egl_state.display, raw_data(config_attribs), &config, 1, &num_config)
	egl_state.ctx = egl.CreateContext(egl_state.display, config, nil, nil)
	egl_state.window = wl.egl_window_create(wl_state.surface, 1280, 720)
	egl_state.surface = egl.CreateWindowSurface(
		egl_state.display,
		config,
		cast(egl.NativeWindowType)egl_state.window,
		nil,
	)
	wl.surface_commit(wl_state.surface)
	egl.MakeCurrent(egl_state.display, egl_state.surface, egl_state.surface, egl_state.ctx)
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, egl.gl_set_proc_address)

	egl.SwapInterval(egl_state.display, 1)
}

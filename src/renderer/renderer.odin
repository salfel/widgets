package renderer

import wl "../../lib/wayland"

Renderer :: struct {
	wl_state:       Wayland_State,
	egl_state:      Egl_State,
	libdecor_state: Libdecor_State,
}

g_Renderer: Renderer

renderer_init :: proc(app_id, title: cstring) {
	wayland_init()
	egl_init()
	libdecor_init(app_id, title)
}

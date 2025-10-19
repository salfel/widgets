package renderer

import wl "../../lib/wayland"

Window_State :: struct {
	wl_state:       Wayland_State,
	egl_state:      Egl_State,
	libdecor_state: Libdecor_State,
}

window_init :: proc(window_state: ^Window_State, app_id, title: cstring) {
	wayland_init(&window_state.wl_state)
	egl_init(&window_state.egl_state, &window_state.wl_state)
	libdecor_init(window_state, app_id, title)
}

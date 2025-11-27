package main

import "core:fmt"
import "core:os"
import "core:sys/linux"
import wl "lib:wayland"
import gl "vendor:OpenGL"
import "vendor:egl"

TIMEOUT :: 5000

Renderer :: struct {
	dirty: bool, // move to layout manager
	exit:  bool,
	fd:    linux.Fd,
}

renderer_init :: proc(renderer: ^Renderer) {
	renderer.dirty = true
}

renderer_loop :: proc(app_context: ^App_Context) {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	egl.SwapBuffers(app_context.window.egl.display, app_context.window.egl.surface)

	fd := wl.display_get_fd(app_context.window.wl.display)
	pollfds := []linux.Poll_Fd{{fd = cast(linux.Fd)fd, events = {.IN}}, {fd = app_context.renderer.fd, events = {.IN}}}

	for !app_context.renderer.exit {
		wl.display_dispatch_pending(app_context.window.wl.display)

		for wl.display_prepare_read(app_context.window.wl.display) == -1 {
			wl.display_dispatch_pending(app_context.window.wl.display)
		}

		wl.display_flush(app_context.window.wl.display)

		if ret, err := linux.poll(pollfds, TIMEOUT); err != nil || ret < 0 {
			if err == .EINTR {
				wl.display_cancel_read(app_context.window.wl.display)
				continue
			}

			fmt.eprintln("poll error:", err)
			wl.display_cancel_read(app_context.window.wl.display)
			break
		}

		if .IN in pollfds[0].revents {
			wl.display_read_events(app_context.window.wl.display)
			wl.display_dispatch_pending(app_context.window.wl.display)
		} else {
			wl.display_cancel_read(app_context.window.wl.display)
		}

		if .IN in pollfds[1].revents {
			buffer := [16]byte{}
			size, _ := os.read(cast(os.Handle)app_context.renderer.fd, buffer[:])

			async_resource_manager_generate_textures(&app_context.async_resource_manager)

			app_context.window.wl.should_render = true
		}

		handle_events(app_context)

		if app_context.window.wl.should_render {
			renderer_render(app_context)

			app_context.window.wl.should_render = false
		}

	}
}

renderer_render :: proc(app_context: ^App_Context) {
	gl.ClearColor(0, 0, 0, 0)
	gl.ClearStencil(0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	if app_context.renderer.dirty {
		layout_measure(&app_context.widget_manager.viewport.layout)
		layout_compute(&app_context.widget_manager.viewport.layout, app_context.window.size.x)
		layout_arrange(&app_context.widget_manager.viewport.layout)

		for _, widget in app_context.widget_manager.widgets {
			widget->recalculate_mp(app_context)
		}

		app_context.renderer.dirty = false
	}

	app_context.widget_manager.viewport->draw(app_context, 1)

	egl.SwapBuffers(app_context.window.egl.display, app_context.window.egl.surface)
}

package main

import "core:fmt"
import "core:os"
import "core:sys/linux"
import wl "lib:wayland"
import gl "vendor:OpenGL"
import "vendor:egl"

Renderer :: struct {
	dirty: bool, // move to layout manager
	exit:  bool,
}

renderer_init :: proc(renderer: ^Renderer) {
	renderer.dirty = true
}

TIMEOUT :: 5000

renderer_loop :: proc(app_context: ^App_Context) {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	egl.SwapBuffers(app_context.window.egl.display, app_context.window.egl.surface)

	fd := wl.display_get_fd(app_context.window.wl.display)

	for !app_context.renderer.exit {
		wl.display_dispatch_pending(app_context.window.wl.display)

		for wl.display_prepare_read(app_context.window.wl.display) == -1 {
			wl.display_dispatch_pending(app_context.window.wl.display)
		}

		wl.display_flush(app_context.window.wl.display)

		pollfds := make([]linux.Poll_Fd, len(app_context.timer.fds) + 1)
		defer delete(pollfds)

		pollfds[0] = {
			fd     = cast(linux.Fd)fd,
			events = {.IN},
		}
		for timer_data, i in app_context.timer.fds {
			pollfds[i + 1] = {
				fd     = timer_data.fd,
				events = {.IN},
			}
		}

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

		for poll_fd, i in pollfds[1:] {
			if .IN not_in poll_fd.revents {
				continue
			}

			timer_data := app_context.timer.fds[i]

			buffer := [8]byte{}
			os.read(cast(os.Handle)timer_data.fd, buffer[:])

			timer_data.handler(timer_data.data)
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

	for app_context.renderer.dirty {
		app_context.renderer.dirty = false

		layout_measure(&app_context.widget_manager.viewport.layout)
		layout_compute(&app_context.widget_manager.viewport.layout, app_context.window.size.x)
		layout_arrange(&app_context.widget_manager.viewport.layout)

		for _, widget in app_context.widget_manager.widgets {
			if widget.layout.dirty {
				widget->recalculate_mp(app_context)

				if widget.resize != nil && widget->resize() {
					app_context.renderer.dirty = true
				}
			}
		}
	}

	app_context.widget_manager.viewport->draw(app_context, 1)

	egl.SwapBuffers(app_context.window.egl.display, app_context.window.egl.surface)
}

package main

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

renderer_loop :: proc(app_context: ^App_Context) {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	egl.SwapBuffers(app_context.window.egl.display, app_context.window.egl.surface)

	for wl.display_dispatch(app_context.window.wl.display) != -1 && !app_context.renderer.exit {
		handle_events(app_context)
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
			if widget.layout.dirty {
				widget->recalculate_mp(app_context)
			}
		}

		app_context.renderer.dirty = false
	}

	app_context.widget_manager.viewport->draw(app_context, 1)

	egl.SwapBuffers(app_context.window.egl.display, app_context.window.egl.surface)
}

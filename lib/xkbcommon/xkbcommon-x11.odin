/*
 * Copyright © 2013 Ran Benita
 * SPDX-License-Identifier: MIT
 */
package xkbcommon

/**
 * @file
 * libxkbcommon-x11 API - Additional X11 support for xkbcommon.
 */

/**
 * @defgroup x11 X11 support
 * Additional X11 support for xkbcommon.
 * @since 0.4.0
 *
 * @{
 */

/**
 * @page x11-overview Overview
 * @parblock
 *
 * The xkbcommon-x11 module provides a means for creating an keymap
 * corresponding to the currently active keymap on the X server.  To do
 * so, it queries the XKB X11 extension using the xcb-xkb library.  It
 * can be used as a replacement for Xlib’s keyboard handling.
 *
 * Following is an example workflow using xkbcommon-x11.  A complete
 * example may be found in the `tools/interactive-x11.c` file in the
 * xkbcommon source repository.  On startup:
 *
 * 1. Connect to the X server using `xcb_connect()`.
 * 2. Setup the XKB X11 extension.  You can do this either by using the
 *    `xcb_xkb_use_extension()` request directly, or by using the
 *    `x11_setup_xkb_extension()` helper function.
 *
 * The XKB extension supports using separate keymaps and states for
 * different keyboard devices.  The devices are identified by an integer
 * device ID and are managed by another X11 extension, XInput. The
 * original X11 protocol only had one keyboard device, called the *core
 * keyboard*, which is still supported as a *virtual device*.
 *
 * 3. We will use the core keyboard as an example.  To get its device ID,
 *    use either the `xcb_xkb_get_device_info()` request directly, or the
 *    `x11_get_core_keyboard_device_id()` helper function.
 * 4. Create an initial keymap for this device, using the
 *    `x11_keymap_new_from_device()` function.
 * 5. Create an initial state for this device, using the
 *    `x11_state_new_from_device()` function.
 *
 * @note At this point, you may consider setting various XKB controls and
 * XKB per-client flags.  For example, enabling detectable autorepeat: \n
 * https://www.x.org/releases/current/doc/kbproto/xkbproto.html#Detectable_Autorepeat
 *
 * Next, you need to react to state changes (e.g. a modifier was pressed,
 * the layout was changed) and to keymap changes (e.g. a tool like xkbcomp,
 * setxkbmap or xmodmap was used):
 *
 * 6. Select to listen to at least the following XKB events:
 *    `NewKeyboardNotify`, `MapNotify`, `StateNotify`; using the
 *    `xcb_xkb_select_events_aux()` request.
 * 7. When `NewKeyboardNotify` or `MapNotify` are received, recreate the
 *    `keymap` and `state` as described above.
 * 8. When `StateNotify` is received, update the `state` accordingly
 *    using the `state::state_update_mask()` function.
 *
 * @note It is also possible to use the `KeyPress`/`KeyRelease` @p state
 * field to find the effective modifier and layout state, instead of
 * using `XkbStateNotify`: \n
 * https://www.x.org/releases/current/doc/kbproto/xkbproto.html#Computing_A_State_Field_from_an_XKB_State
 * \n However, `XkbStateNotify` is more accurate.
 *
 * @note There is no need to call `state_update_key()`; the state is
 * already synchronized.
 *
 * Finally, when a key event is received, you can use ordinary xkbcommon
 * functions, like `state::state_key_get_one_sym()` and
 * `state::state_key_get_utf8()`, as you normally would.
 *
 * @endparblock
 */

/**
 * The minimal compatible major version of the XKB X11 extension which
 * this library can use.
 */
X11_MIN_MAJOR_XKB_VERSION :: 1

/**
 * The minimal compatible minor version of the XKB X11 extension which
 * this library can use (for the minimal major version).
 */
X11_MIN_MINOR_XKB_VERSION :: 0

/** Flags for the `x11_setup_xkb_extension()` function. */
x11_setup_xkb_extension_flags :: enum u32 {
	x11_Setup_Xkb_Extension_No_Flags = 0,
}

foreign import lib "system:xkbcommon"
@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Setup the XKB X11 extension for this X client.
	 *
	 * The xkbcommon-x11 library uses various XKB requests.  Before doing so,
	 * an X client must notify the server that it will be using the extension.
	 * This function (or an XCB equivalent) must be called before any other
	 * function in this library is used.
	 *
	 * Some X servers may not support or disable the XKB extension.  If you
	 * want to support such servers, you need to use a different fallback.
	 *
	 * You may call this function several times; it is idempotent.
	 *
	 * @param connection
	 *     An XCB connection to the X server.
	 * @param major_xkb_version
	 *     See @p minor_xkb_version.
	 * @param minor_xkb_version
	 *     The XKB extension version to request.  To operate correctly, you
	 *     must have (@p major_xkb_version, @p minor_xkb_version) >=
	 *     (`XKB_X11_MIN_MAJOR_XKB_VERSION`, `XKB_X11_MIN_MINOR_XKB_VERSION`),
	 *     though this is not enforced.
	 * @param flags
	 *     Optional flags, or 0.
	 * @param[out] major_xkb_version_out
	 *     See @p minor_xkb_version_out.
	 * @param[out] minor_xkb_version_out
	 *     Backfilled with the compatible XKB extension version numbers picked
	 *     by the server.  Can be `NULL`.
	 * @param[out] base_event_out
	 *     Backfilled with the XKB base (also known as first) event code, needed
	 *     to distinguish XKB events.  Can be `NULL`.
	 * @param[out] base_error_out
	 *     Backfilled with the XKB base (also known as first) error code, needed
	 *     to distinguish XKB errors.  Can be `NULL`.
	 *
	 * @returns 1 on success, or 0 on failure.
	 */
	x11_setup_xkb_extension :: proc(connection: ^i32, major_xkb_version: i32, minor_xkb_version: i32, flags: x11_setup_xkb_extension_flags, major_xkb_version_out: ^i32, minor_xkb_version_out: ^i32, base_event_out: ^i32, base_error_out: ^i32) -> i32 ---

	/**
	 * Create a keymap from an X11 keyboard device.
	 *
	 * This function queries the X server with various requests, fetches the
	 * details of the active keymap on a keyboard device, and creates an
	 * keymap from these details.
	 *
	 * @param context
	 *     The context in which to create the keymap.
	 * @param connection
	 *     An XCB connection to the X server.
	 * @param device_id
	 *     An XInput device ID (in the range 0-127) with input class KEY.
	 *     Passing values outside of this range is an error (the XKB protocol
	 *     predates the XInput2 protocol, which first allowed IDs > 127).
	 * @param flags
	 *     Optional flags for the keymap, or 0.
	 *
	 * @returns A keymap retrieved from the X server, or `NULL` on failure.
	 *
	 * @memberof keymap
	 */
	x11_keymap_new_from_device :: proc(_context: ^ctx, connection: ^i32, device_id: i32, flags: keymap_compile_flags) -> ^i32 ---

	/**
	 * Create a new keyboard state object from an X11 keyboard device.
	 *
	 * This function is the same as `state_new()`, only pre-initialized
	 * with the state of the device at the time this function is called.
	 *
	 * @param keymap
	 *     The keymap for which to create the state.
	 * @param connection
	 *     An XCB connection to the X server.
	 * @param device_id
	 *     An XInput 1 device ID (in the range 0-255) with input class KEY.
	 *     Passing values outside of this range is an error.
	 *
	 * @returns A new keyboard state object, or `NULL` on failure.
	 *
	 * @memberof state
	 */
	x11_state_new_from_device :: proc(keymap: ^keymap, connection: ^i32, device_id: i32) -> ^i32 ---
}

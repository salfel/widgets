/*
 * Copyright © 2013 Ran Benita
 * SPDX-License-Identifier: MIT
 */
package xkbcommon

/**
 * @struct compose_table
 * Opaque Compose table object.
 *
 * The compose table holds the definitions of the Compose sequences, as
 * gathered from Compose files.  It is immutable.
 */
compose_table :: struct {}

/**
 * @struct compose_state
 * Opaque Compose state object.
 *
 * The compose state maintains state for compose sequence matching, such
 * as which possible sequences are being matched, and the position within
 * these sequences.  It acts as a simple state machine wherein keysyms are
 * the input, and composed keysyms and strings are the output.
 *
 * The compose state is usually associated with a keyboard device.
 */
compose_state :: struct {}

/** Flags affecting Compose file compilation. */
compose_compile_flags :: enum u32 {
	NO_FLAGS = 0,
}

/** The recognized Compose file formats. */
compose_format :: enum u32 {
	Text_V1 = 1,
}


foreign import lib "system:xkbcommon"
@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Create a compose table for a given locale.
	 *
	 * The locale is used for searching the file-system for an appropriate
	 * Compose file.  The search order is described in Compose(5).  It is
	 * affected by the following environment variables:
	 *
	 * 1. `XCOMPOSEFILE` - see Compose(5).
	 * 2. `XDG_CONFIG_HOME` - before `$HOME/.XCompose` is checked,
	 *    `$XDG_CONFIG_HOME/XCompose` is checked (with a fall back to
	 *    `$HOME/.config/XCompose` if `XDG_CONFIG_HOME` is not defined).
	 *    This is a libxkbcommon extension to the search procedure in
	 *    Compose(5) (since libxkbcommon 1.0.0). Note that other
	 *    implementations, such as libX11, might not find a Compose file in
	 *    this path.
	 * 3. `HOME` - see Compose(5).
	 * 4. `XLOCALEDIR` - if set, used as the base directory for the system’s
	 *    X locale files, e.g. `/usr/share/X11/locale`, instead of the
	 *    preconfigured directory.
	 *
	 * Since 1.12, system locales not registered in `$XLOCALEDIR` will fallback
	 * to `en_US.UTF-8`.
	 *
	 * @param context
	 *     The library context in which to create the compose table.
	 * @param locale
	 *     The current locale.  See @ref compose-locale.
	 *     \n
	 *     The value is copied, so it is safe to pass the result of `getenv(3)`
	 *     (or similar) without fear of it being invalidated by a subsequent
	 *     `setenv(3)` (or similar).
	 * @param flags
	 *     Optional flags for the compose table, or 0.
	 *
	 * @returns A compose table for the given locale, or `NULL` if the
	 * compilation failed or a Compose file was not found.
	 *
	 * @memberof compose_table
	 */
	compose_table_new_from_locale :: proc(_context: ^ctx, locale: cstring, flags: compose_compile_flags) -> ^i32 ---

	/**
	 * Create a new compose table from a Compose file.
	 *
	 * @param context
	 *     The library context in which to create the compose table.
	 * @param file
	 *     The Compose file to compile.
	 * @param locale
	 *     The current locale.  See @ref compose-locale.
	 * @param format
	 *     The text format of the Compose file to compile.
	 * @param flags
	 *     Optional flags for the compose table, or 0.
	 *
	 * @returns A compose table compiled from the given file, or `NULL` if
	 * the compilation failed.
	 *
	 * @memberof compose_table
	 */
	compose_table_new_from_file :: proc(_context: ^ctx, file: ^i32, locale: cstring, format: compose_format, flags: compose_compile_flags) -> ^i32 ---

	/**
	 * Create a new compose table from a memory buffer.
	 *
	 * This is just like compose_table_new_from_file(), but instead of
	 * a file, gets the table as one enormous string.
	 *
	 * @see compose_table_new_from_file()
	 * @memberof compose_table
	 */
	compose_table_new_from_buffer :: proc(_context: ^ctx, buffer: cstring, length: i32, locale: cstring, format: compose_format, flags: compose_compile_flags) -> ^i32 ---

	/**
	 * Take a new reference on a compose table.
	 *
	 * @returns The passed in object.
	 *
	 * @memberof compose_table
	 */
	compose_table_ref :: proc(table: ^compose_table) -> ^i32 ---

	/**
	 * Release a reference on a compose table, and possibly free it.
	 *
	 * @param table The object.  If it is `NULL`, this function does nothing.
	 *
	 * @memberof compose_table
	 */
	compose_table_unref :: proc(table: ^compose_table) -> i32 ---
}

/**
 * @struct compose_table_entry
 * Opaque Compose table entry object.
 *
 * Represents a single entry in a Compose file in the iteration API.
 * It is immutable.
 *
 * @sa compose_table_iterator_new
 * @since 1.6.0
 */
compose_table_entry :: struct {}

@(default_calling_convention = "c")
foreign lib {

	/**
	 * Get the right-hand result string of a Compose table entry.
	 *
	 * The string is UTF-8 encoded and `NULL`-terminated.
	 *
	 * For example, given the following entry:
	 *
	 * ```
	 * <dead_tilde> <space> : "~" asciitilde # TILDE
	 * ```
	 *
	 * it will return `"~"`.
	 *
	 * The string is optional; if the entry does not specify a string,
	 * returns the empty string.
	 *
	 * @memberof compose_table_entry
	 * @since 1.6.0
	 */
	compose_table_entry_utf8 :: proc(entry: ^compose_table_entry) -> ^i32 ---
}

/**
 * @struct compose_table_iterator
 * Iterator over a compose table’s entries.
 *
 * @sa compose_table_iterator_new()
 * @since 1.6.0
 */
compose_table_iterator :: struct {}

@(default_calling_convention = "c")
foreign lib {

	/**
	 * Create a new iterator for a compose table.
	 *
	 * Intended use:
	 *
	 * ```c
	 * struct compose_table_iterator *iter = compose_table_iterator_new(compose_table);
	 * struct compose_table_entry *entry;
	 * while ((entry = compose_table_iterator_next(iter))) {
	 *     // ...
	 * }
	 * compose_table_iterator_free(iter);
	 * ```
	 *
	 * @returns A new compose table iterator, or `NULL` on failure.
	 *
	 * @memberof compose_table_iterator
	 * @sa compose_table_iterator_free()
	 * @since 1.6.0
	 */
	compose_table_iterator_new :: proc(table: ^compose_table) -> ^i32 ---

	/**
	 * Free a compose iterator.
	 *
	 * @memberof compose_table_iterator
	 * @since 1.6.0
	 */
	compose_table_iterator_free :: proc(iter: ^compose_table_iterator) -> i32 ---

	/**
	 * Get the next compose entry from a compose table iterator.
	 *
	 * The entries are returned in lexicographic order of the left-hand
	 * side of entries. This does not correspond to the order in which
	 * the entries appear in the Compose file.
	 *
	 * @attention The return value is valid until the next call to this function.
	 *
	 * Returns `NULL` in case there is no more entries.
	 *
	 * @memberof compose_table_iterator
	 * @since 1.6.0
	 */
	compose_table_iterator_next :: proc(iter: ^compose_table_iterator) -> ^i32 ---
}

/** Flags for compose state creation. */
compose_state_flags :: enum u32 {
	No_Flags = 0,
}

@(default_calling_convention = "c")
foreign lib {

	/**
	 * Create a new compose state object.
	 *
	 * @param table
	 *     The compose table the state will use.
	 * @param flags
	 *     Optional flags for the compose state, or 0.
	 *
	 * @returns A new compose state, or `NULL` on failure.
	 *
	 * @memberof compose_state
	 */
	compose_state_new :: proc(table: ^compose_table, flags: compose_state_flags) -> ^i32 ---

	/**
	 * Take a new reference on a compose state object.
	 *
	 * @returns The passed in object.
	 *
	 * @memberof compose_state
	 */
	compose_state_ref :: proc(state: ^compose_state) -> ^i32 ---

	/**
	 * Release a reference on a compose state object, and possibly free it.
	 *
	 * @param state The object.  If `NULL`, do nothing.
	 *
	 * @memberof compose_state
	 */
	compose_state_unref :: proc(state: ^compose_state) -> i32 ---

	/**
	 * Get the compose table which a compose state object is using.
	 *
	 * @returns The compose table which was passed to compose_state_new()
	 * when creating this state object.
	 *
	 * This function does not take a new reference on the compose table; you
	 * must explicitly reference it yourself if you plan to use it beyond the
	 * lifetime of the state.
	 *
	 * @memberof compose_state
	 */
	compose_state_get_compose_table :: proc(state: ^compose_state) -> ^i32 ---
}

/** Status of the Compose sequence state machine. */
compose_status :: enum u32 {
	Nothing   = 0,
	Composing = 1,
	Composed  = 2,
	Cancelled = 3,
}

/** The effect of a keysym fed to compose_state_feed(). */
compose_feed_result :: enum u32 {
	Ignored  = 0,
	Accepted = 1,
}

@(default_calling_convention = "c")
foreign lib {

	/**
	 * Feed one keysym to the Compose sequence state machine.
	 *
	 * This function can advance into a compose sequence, cancel a sequence,
	 * start a new sequence, or do nothing in particular.  The resulting
	 * status may be observed with `compose_state_get_status()`.
	 *
	 * Some keysyms, such as keysyms for modifier keys, are ignored - they
	 * have no effect on the status or otherwise.
	 *
	 * The following is a description of the possible status transitions, in
	 * the format CURRENT STATUS => NEXT STATUS, given a non-ignored input
	 * keysym `keysym`:
	 *
	   @verbatim
	   NOTHING or CANCELLED or COMPOSED =>
	      NOTHING   if keysym does not start a sequence.
	      COMPOSING if keysym starts a sequence.
	      COMPOSED  if keysym starts and terminates a single-keysym sequence.
	
	   COMPOSING =>
	      COMPOSING if keysym advances any of the currently possible
	                sequences but does not terminate any of them.
	      COMPOSED  if keysym terminates one of the currently possible
	                sequences.
	      CANCELLED if keysym does not advance any of the currently
	                possible sequences.
	   @endverbatim
	 *
	 * The current Compose formats do not support multiple-keysyms. Therefore, if
	 * you are using a function such as `state::state_key_get_syms()`
	 * and it returns more than one keysym, consider feeding `XKB_KEY_NoSymbol`
	 * instead.
	 *
	 * @param state
	 *     The compose state object.
	 * @param keysym
	 *     A keysym, usually obtained after a key-press event, with a
	 *     function such as `state::state_key_get_one_sym()`.
	 *
	 * @returns Whether the keysym was ignored.  This is useful, for example,
	 * if you want to keep a record of the sequence matched thus far.
	 *
	 * @memberof compose_state
	 */
	compose_state_feed :: proc(state: ^compose_state, keysym: i32) -> i32 ---

	/**
	 * Reset the Compose sequence state machine.
	 *
	 * The status is set to `::XKB_COMPOSE_NOTHING`, and the current sequence
	 * is discarded.
	 *
	 * @memberof compose_state
	 */
	compose_state_reset :: proc(state: ^compose_state) -> i32 ---

	/**
	 * Get the current status of the compose state machine.
	 *
	 * @see compose_status
	 * @memberof compose_state
	 **/
	compose_state_get_status :: proc(state: ^compose_state) -> i32 ---

	/**
	 * Get the result Unicode/UTF-8 string for a composed sequence.
	 *
	 * See @ref compose-overview for more details.  This function is only
	 * useful when the status is `::XKB_COMPOSE_COMPOSED`.
	 *
	 * @param[in] state
	 *     The compose state.
	 * @param[out] buffer
	 *     A buffer to write the string into.
	 * @param[in] size
	 *     Size of the buffer.
	 *
	 * @warning If the buffer passed is too small, the string is truncated
	 * (though still `NULL`-terminated).
	 *
	 * @returns
	 *   The number of bytes required for the string, excluding the `NULL` byte.
	 *   If the sequence is not complete, or does not have a viable result
	 *   string, returns 0, and sets `buffer` to the empty string (if possible).
	 * @returns
	 *   You may check if truncation has occurred by comparing the return value
	 *   with the size of `buffer`, similarly to the `snprintf(3)` function.
	 *   You may safely pass `NULL` and 0 to `buffer` and `size` to find the
	 *   required size (without the `NULL`-byte).
	 *
	 * @memberof compose_state
	 **/
	compose_state_get_utf8 :: proc(state: ^compose_state, buffer: ^i8, size: i32) -> i32 ---
}

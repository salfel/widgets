/*
 * For MIT-open-group:
 * Copyright 1985, 1987, 1990, 1998  The Open Group
 * Copyright 2008  Dan Nicholson
 *
 * For HPND:
 * Copyright (c) 1993 by Silicon Graphics Computer Systems, Inc.
 * SPDX-License-Identifier: HPND
 *
 * For MIT:
 * Copyright © 2009-2012 Daniel Stone
 * Copyright © 2012 Intel Corporation
 * Copyright © 2012 Ran Benita
 *
 * SPDX-License-Identifier: MIT-open-group AND HPND AND MIT
 *
 * Author: Daniel Stone <daniel@fooishbar.org>
 */
package xkbcommon

/**
 * @struct context
 * Opaque top level library context object.
 *
 * The context contains various general library data and state, like
 * logging level and include paths.
 *
 * Objects are created in a specific context, and multiple contexts may
 * coexist simultaneously.  Objects from different contexts are completely
 * separated and do not share any memory or state.
 */
ctx :: struct {}

/**
 * @struct keymap
 * Opaque compiled keymap object.
 *
 * The keymap object holds all of the static keyboard information obtained
 * from compiling XKB files.
 *
 * A keymap is immutable after it is created (besides reference counts, etc.);
 * if you need to change it, you must create a new one.
 */
keymap :: struct {}

/**
 * @struct state
 * Opaque keyboard state object.
 *
 * State objects contain the active state of a keyboard (or keyboards), such
 * as the currently effective layout and the active modifiers.  It acts as a
 * simple state machine, wherein key presses and releases are the input, and
 * key symbols (keysyms) are the output.
 */
state :: struct {}

/**
 * A number used to represent a physical key on a keyboard.
 *
 * A standard PC-compatible keyboard might have 102 keys.  An appropriate
 * keymap would assign each of them a keycode, by which the user should
 * refer to the key throughout the library.
 *
 * Historically, the X11 protocol, and consequentially the XKB protocol,
 * assign only 8 bits for keycodes.  This limits the number of different
 * keys that can be used simultaneously in a single keymap to 256
 * (disregarding other limitations).  This library does not share this limit;
 * keycodes beyond 255 (*extended* keycodes) are not treated specially.
 * Keymaps and applications which are compatible with X11 should not use
 * these keycodes.
 *
 * The values of specific keycodes are determined by the keymap and the
 * underlying input system.  For example, with an X11-compatible keymap
 * and Linux evdev scan codes (see `linux/input.h`), a fixed offset is used:
 *
 * The keymap defines a canonical name for each key, plus possible aliases.
 * Historically, the XKB protocol restricts these names to at most 4 (ASCII)
 * characters, but this library does not share this limit.
 *
 * @code
 * keycode_t keycode_A = KEY_A + 8;
 * @endcode
 *
 * @sa keycode_is_legal_ext() keycode_is_legal_x11()
 */
keycode_t :: i32

/**
 * A number used to represent the symbols generated from a key on a keyboard.
 *
 * A key, represented by a keycode, may generate different symbols according
 * to keyboard state.  For example, on a QWERTY keyboard, pressing the key
 * labled <A> generates the symbol ‘a’.  If the Shift key is held, it
 * generates the symbol ‘A’.  If a different layout is used, say Greek,
 * it generates the symbol ‘α’.  And so on.
 *
 * Each such symbol is represented by a *keysym* (short for “key symbol”).
 * Note that keysyms are somewhat more general, in that they can also represent
 * some “function”, such as “Left” or “Right” for the arrow keys.  For more
 * information, see: Appendix A [“KEYSYM Encoding”][encoding] of the X Window
 * System Protocol.
 *
 * Specifically named keysyms can be found in the
 * xkbcommon/xkbcommon-keysyms.h header file.  Their name does not include
 * the `XKB_KEY_` prefix.
 *
 * Besides those, any Unicode/ISO 10646 character in the range U+0100 to
 * U+10FFFF can be represented by a keysym value in the range 0x01000100 to
 * 0x0110FFFF.  The name of Unicode keysyms is `U<codepoint>`, e.g. `UA1B2`.
 *
 * The name of other unnamed keysyms is the hexadecimal representation of
 * their value, e.g. `0xabcd1234`.
 *
 * Keysym names are case-sensitive.
 *
 * @note **Encoding:** Keysyms are 32-bit integers with the 3 most significant
 * bits always set to zero.  Thus valid keysyms are in the range
 * `0 .. 0x1fffffff` = @ref XKB_KEYSYM_MAX.
 * See: Appendix A [“KEYSYM Encoding”][encoding] of the X Window System Protocol.
 *
 * [encoding]: https://www.x.org/releases/current/doc/xproto/x11protocol.html#keysym_encoding
 *
 * @ingroup keysyms
 * @sa `::XKB_KEYSYM_MAX`
 */
keysym_t :: i32

/**
 * Index of a keyboard layout.
 *
 * The layout index is a state component which determines which <em>keyboard
 * layout</em> is active.  These may be different alphabets, different key
 * arrangements, etc.
 *
 * Layout indices are consecutive.  The first layout has index 0.
 *
 * Each layout is not required to have a name, and the names are not
 * guaranteed to be unique (though they are usually provided and unique).
 * Therefore, it is not safe to use the name as a unique identifier for a
 * layout.  Layout names are case-sensitive.
 *
 * Layout names are specified in the layout’s definition, for example
 * “English (US)”.  These are different from the (conventionally) short names
 * which are used to locate the layout, for example `us` or `us(intl)`.  These
 * names are not present in a compiled keymap.
 *
 * If the user selects layouts from a list generated from the XKB registry
 * (using libxkbregistry or directly), and this metadata is needed later on, it
 * is recommended to store it along with the keymap.
 *
 * Layouts are also called *groups* by XKB.
 *
 * @sa keymap::keymap_num_layouts()
 * @sa keymap::keymap_num_layouts_for_key()
 */
layout_index_t :: i32

/** A mask of layout indices. */
layout_mask_t :: i32

/**
 * Index of a shift level.
 *
 * Any key, in any layout, can have several <em>shift levels</em>.  Each
 * shift level can assign different keysyms to the key.  The shift level
 * to use is chosen according to the current keyboard state; for example,
 * if no keys are pressed, the first level may be used; if the Left Shift
 * key is pressed, the second; if Num Lock is pressed, the third; and
 * many such combinations are possible (see `mod_index_t`).
 *
 * Level indices are consecutive.  The first level has index 0.
 */
level_index_t :: i32

/**
 * Index of a modifier.
 *
 * A @e modifier is a state component which changes the way keys are
 * interpreted.  A keymap defines a set of modifiers, such as Alt, Shift,
 * Num Lock or Meta, and specifies which keys may @e activate which
 * modifiers (in a many-to-many relationship, i.e. a key can activate
 * several modifiers, and a modifier may be activated by several keys.
 * Different keymaps do this differently).
 *
 * When retrieving the keysyms for a key, the active modifier set is
 * consulted; this determines the correct shift level to use within the
 * currently active layout (see `level_index_t`).
 *
 * Modifier indices are consecutive.  The first modifier has index 0.
 *
 * Each modifier must have a name, and the names are unique.  Therefore, it
 * is safe to use the name as a unique identifier for a modifier.  The names
 * of some common modifiers are provided in the `xkbcommon/xkbcommon-names.h`
 * header file.  Modifier names are case-sensitive.
 *
 * @sa keymap_num_mods()
 */
mod_index_t :: i32

/** A mask of modifier indices. */
mod_mask_t :: i32

/**
 * Index of a keyboard LED.
 *
 * LEDs are logical objects which may be @e active or @e inactive.  They
 * typically correspond to the lights on the keyboard. Their state is
 * determined by the current keyboard state.
 *
 * LED indices are non-consecutive.  The first LED has index 0.
 *
 * Each LED must have a name, and the names are unique. Therefore,
 * it is safe to use the name as a unique identifier for a LED.  The names
 * of some common LEDs are provided in the `xkbcommon/xkbcommon-names.h`
 * header file.  LED names are case-sensitive.
 *
 * @warning A given keymap may specify an exact index for a given LED.
 * Therefore, LED indexing is not necessarily sequential, as opposed to
 * modifiers and layouts.  This means that when iterating over the LEDs
 * in a keymap using e.g. keymap::keymap_num_leds(), some indices might
 * be invalid.
 * Given such an index, functions like keymap::keymap_led_get_name()
 * will return `NULL`, and `state::state_led_index_is_active()` will
 * return -1.
 *
 * LEDs are also called *indicators* by XKB.
 *
 * @sa `keymap::keymap_num_leds()`
 */
led_index_t :: i32

/** A mask of LED indices. */
led_mask_t :: i32


/** Invalid keycode */
XKB_KEYCODE_INVALID :: (0xffffffff)

/** Invalid layout index */
XKB_LAYOUT_INVALID :: (0xffffffff)

/** Invalid level index */
XKB_LEVEL_INVALID :: (0xffffffff)

/** Invalid modifier index */
XKB_MOD_INVALID :: (0xffffffff)

/** Invalid LED index */
XKB_LED_INVALID :: (0xffffffff)

/** Maximum legal keycode */
XKB_KEYCODE_MAX :: (0xffffffff - 1)

/**
 * Maximum keysym value
 *
 * @since 1.6.0
 * @sa keysym_t
 * @ingroup keysyms
 */
XKB_KEYSYM_MAX :: 0x1fffffff

/**
 * @struct rmlvo_builder
 * Opaque [RMLVO] configuration object.
 *
 * It denotes the configuration values by which a user picks a keymap.
 *
 * @see [Introduction to RMLVO][RMLVO]
 * @see @ref rules-api ""
 * @since 1.11.0
 *
 * [RMLVO]: @ref RMLVO-intro
 */
rmlvo_builder :: struct {}

rmlvo_builder_flags :: enum u32 {
	No_Flags = 0,
}

foreign import lib "system:xkbcommon"
@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Create a new [RMLVO] builder.
	 *
	 * @param context The context in which to create the builder.
	 * @param rules   The ruleset.
	 * If `NULL` or the empty string `""`, a default value is used.
	 * If the `XKB_DEFAULT_RULES` environment variable is set, it is used
	 * as the default.  Otherwise the system default is used.
	 * @param model   The keyboard model.
	 * If `NULL` or the empty string `""`, a default value is used.
	 * If the `XKB_DEFAULT_MODEL` environment variable is set, it is used
	 * as the default.  Otherwise the system default is used.
	 * @param flags   Optional flags for the builder, or 0.
	 *
	 * @returns A `rmlvo_builder`, or `NULL` if the compilation failed.
	 *
	 * @see `rule_names` for a detailed description of `rules` and `model`.
	 * @since 1.11.0
	 * @memberof rmlvo_builder
	 *
	 * [RMLVO]: @ref RMLVO-intro
	 */
	rmlvo_builder_new :: proc(_context: ^ctx, rules: cstring, model: cstring, flags: rmlvo_builder_flags) -> ^rmlvo_builder ---

	/**
	 * Append a layout to the given [RMLVO] builder.
	 *
	 * @param rmlvo         The builder to modify.
	 * @param layout        The name of the layout.
	 * @param variant       The name of the layout variant, or `NULL` to
	 * select the default variant.
	 * @param options       An array of options to apply only to this layout, or
	 * `NULL` if there is no such options.
	 * @param options_len   The length of @p options.
	 *
	 * @note The options are only effectual if the corresponding ruleset has the
	 * proper rules to handle them as *layout-specific* options.
	 * @note See `rxkb_option_is_layout_specific()` to query whether an option
	 * supports the layout-specific feature.
	 *
	 * @returns `true` if the call succeeded, otherwise `false`.
	 *
	 * @since 1.11.0
	 * @memberof rmlvo_builder
	 *
	 * [RMLVO]: @ref RMLVO-intro
	 */
	rmlvo_builder_append_layout :: proc(rmlvo: ^rmlvo_builder, layout: cstring, variant: cstring, options: ^cstring, options_len: i32) -> i32 ---

	/**
	 * Append an option to the given [RMLVO] builder.
	 *
	 * @param rmlvo   The builder to modify.
	 * @param option  The name of the option.
	 *
	 * @returns `true` if the call succeeded, otherwise `false`.
	 *
	 * @since 1.11.0
	 * @memberof rmlvo_builder
	 *
	 * [RMLVO]: @ref RMLVO-intro
	 */
	rmlvo_builder_append_option :: proc(rmlvo: ^rmlvo_builder, option: cstring) -> i32 ---

	/**
	 * Take a new reference on a [RMLVO] builder.
	 *
	 * @param rmlvo The builder to reference.
	 *
	 * @returns The passed in builder.
	 *
	 * @since 1.11.0
	 * @memberof rmlvo_builder
	 *
	 * [RMLVO]: @ref RMLVO-intro
	 */
	rmlvo_builder_ref :: proc(rmlvo: ^rmlvo_builder) -> ^rmlvo_builder ---

	/**
	 * Release a reference on a [RMLVO] builder, and possibly free it.
	 *
	 * @param rmlvo The builder.  If it is `NULL`, this function does nothing.
	 *
	 * @since 1.11.0
	 * @memberof rmlvo_builder
	 *
	 * [RMLVO]: @ref RMLVO-intro
	 */
	rmlvo_builder_unref :: proc(rmlvo: ^rmlvo_builder) ---
}

/**
 * Names to compile a keymap with, also known as [RMLVO].
 *
 * The names are the common configuration values by which a user picks
 * a keymap.
 *
 * If the entire struct is `NULL`, then each field is taken to be `NULL`.
 * You should prefer passing `NULL` instead of choosing your own defaults.
 *
 * @see [Introduction to RMLVO][RMLVO]
 * @see @ref rules-api ""
 *
 * [RMLVO]: @ref RMLVO-intro
 */
rule_names :: struct {
	/**
	     * The rules file to use. The rules file describes how to interpret
	     * the values of the model, layout, variant and options fields.
	     *
	     * If `NULL` or the empty string `""`, a default value is used.
	     * If the `XKB_DEFAULT_RULES` environment variable is set, it is used
	     * as the default.  Otherwise the system default is used.
	     */
	rules:   cstring,
	/**
	     * The keyboard model by which to interpret keycodes and LEDs.
	     *
	     * If `NULL` or the empty string `""`, a default value is used.
	     * If the `XKB_DEFAULT_MODEL` environment variable is set, it is used
	     * as the default.  Otherwise the system default is used.
	     */
	model:   cstring,
	/**
	     * A comma separated list of layouts (languages) to include in the
	     * keymap.
	     *
	     * If `NULL` or the empty string `""`, a default value is used.
	     * If the `XKB_DEFAULT_LAYOUT` environment variable is set, it is used
	     * as the default.  Otherwise the system default is used.
	     */
	layout:  cstring,
	/**
	     * A comma separated list of variants, one per layout, which may
	     * modify or augment the respective layout in various ways.
	     *
	     * Generally, should either be empty or have the same number of values
	     * as the number of layouts. You may use empty values as in `intl,,neo`.
	     *
	     * If `NULL` or the empty string `""`, and a default value is also used
	     * for the layout, a default value is used.  Otherwise no variant is
	     * used.
	     * If the `XKB_DEFAULT_VARIANT` environment variable is set, it is used
	     * as the default.  Otherwise the system default is used.
	     */
	variant: cstring,
	/**
	     * A comma separated list of options, through which the user specifies
	     * non-layout related preferences, like which key combinations are used
	     * for switching layouts, or which key is the Compose key.
	     *
	     * If `NULL`, a default value is used.  If the empty string `""`, no
	     * options are used.
	     * If the `XKB_DEFAULT_OPTIONS` environment variable is set, it is used
	     * as the default.  Otherwise the system default is used.
	     *
	     * Each option can additionally have a *layout index specifier*, so that it
	     * applies only if matching the given layout.  The index is specified by
	     * appending `!` immediately after the option name, then the 1-indexed
	     * target layout in decimal format: e.g. `ns:option!2`.  When no layout is
	     * specified, it matches any layout.
	     *
	     * @note The layout index specifier is only effectual if the corresponding
	     * ruleset has the proper rules to handle the option as *layout-specific*.
	     * @note See `rxkb_option_is_layout_specific()` to query whether an option
	     * supports the layout-specific feature.
	     *
	     * @since 1.11.0: Layout index specifier using `!`.
	     */
	options: cstring,
}

/**
 * Keymap components, also known as [KcCGST].
 *
 * The components are the result of the [RMLVO] resolution.
 *
 * @see [Introduction to RMLVO][RMLVO]
 * @see [Introduction to KcCGST][KcCGST]
 * @see @ref rules-api ""
 *
 * [RMLVO]: @ref RMLVO-intro
 * [KcCGST]: @ref KcCGST-intro
 */
component_names :: struct {
	keycodes:      ^i8,
	compatibility: ^i8,
	geometry:      ^i8,
	symbols:       ^i8,
	types:         ^i8,
}

@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Resolve [RMLVO] names to [KcCGST] components.
	 *
	 * This function is used primarily for *debugging*. See
	 * `keymap::keymap_new_from_names2()` for creating keymaps from
	 * [RMLVO] names.
	 *
	 * @param[in]  context    The context in which to resolve the names.
	 * @param[in]  rmlvo_in   The [RMLVO] names to use.
	 * @param[out] rmlvo_out  The [RMLVO] names actually used after resolving
	 * missing values.
	 * @param[out] components_out The [KcCGST] components resulting of the [RMLVO]
	 * resolution.
	 *
	 * @c rmlvo_out and @c components can be omitted by using `NULL`, but not both.
	 *
	 * If @c components is not `NULL`, it is filled with dynamically-allocated
	 * strings that should be freed by the caller.
	 *
	 * @returns `true` if the [RMLVO] names could be resolved, `false` otherwise.
	 *
	 * @see [Introduction to RMLVO][RMLVO]
	 * @see [Introduction to KcCGST][KcCGST]
	 * @see rule_names
	 * @see component_names
	 * @see keymap::keymap_new_from_names2()
	 *
	 * @since 1.9.0
	 * @memberof component_names
	 *
	 * [RMLVO]: @ref RMLVO-intro
	 * [KcCGST]: @ref KcCGST-intro
	 */
	components_names_from_rules :: proc(_context: ^ctx, rmlvo_in: ^rule_names, rmlvo_out: ^rule_names, components_out: ^component_names) -> i32 ---

	/**
	 * Get the name of a keysym.
	 *
	 * For a description of how keysyms are named, see @ref keysym_t.
	 *
	 * @param[in]  keysym The keysym.
	 * @param[out] buffer A string buffer to write the name into.
	 * @param[in]  size   Size of the buffer.
	 *
	 * @warning If the buffer passed is too small, the string is truncated
	 * (though still `NULL`-terminated); a size of at least 64 bytes is recommended.
	 *
	 * @returns The number of bytes in the name, excluding the `NULL` byte. If
	 * the keysym is invalid, returns -1.
	 *
	 * You may check if truncation has occurred by comparing the return value
	 * with the length of buffer, similarly to the `snprintf(3)` function.
	 *
	 * @sa `keysym_t`
	 */
	keysym_get_name :: proc(keysym: keysym_t, buffer: ^i8, size: i32) -> i32 ---
}

/** Flags for keysym_from_name(). */
keysym_flags :: enum u32 {
	No_Flags         = 0,
	Case_Insensitive = 1,
}

@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Get a keysym from its name.
	 *
	 * @param name The name of a keysym. See remarks in `keysym_get_name()`;
	 * this function will accept any name returned by that function.
	 * @param flags A set of flags controlling how the search is done. If
	 * invalid flags are passed, this will fail with `XKB_KEY_NoSymbol`.
	 *
	 * If you use the `::XKB_KEYSYM_CASE_INSENSITIVE` flag and two keysym names
	 * differ only by case, then the lower-case keysym name is returned.  For
	 * instance, for KEY_a and KEY_A, this function would return KEY_a for the
	 * case-insensitive search.  If this functionality is needed, it is
	 * recommended to first call this function without this flag; and if that
	 * fails, only then to try with this flag, while possibly warning the user
	 * he had misspelled the name, and might get wrong results.
	 *
	 * Case folding is done according to the C locale; the current locale is not
	 * consulted.
	 *
	 * @returns The keysym. If the name is invalid, returns `XKB_KEY_NoSymbol`.
	 *
	 * @sa keysym_t
	 * @since 1.9.0: Enable support for C0 and C1 control characters in the Unicode
	 * notation.
	 */
	keysym_from_name :: proc(name: cstring, flags: keysym_flags) -> keysym_t ---

	/**
	 * Get the Unicode/UTF-8 representation of a keysym.
	 *
	 * @param[in]  keysym The keysym.
	 * @param[out] buffer A buffer to write the UTF-8 string into.
	 * @param[in]  size   The size of buffer.  Must be at least 5.
	 *
	 * @returns The number of bytes written to the buffer (including the
	 * terminating byte).  If the keysym does not have a Unicode
	 * representation, returns 0.  If the buffer is too small, returns -1.
	 *
	 * This function does not perform any @ref keysym-transformations.
	 * Therefore, prefer to use `state::state_key_get_utf8()` if possible.
	 *
	 * @sa `state::state_key_get_utf8()`
	 */
	keysym_to_utf8 :: proc(keysym: keysym_t, buffer: ^i8, size: i32) -> i32 ---

	/**
	 * Get the Unicode/UTF-32 representation of a keysym.
	 *
	 * @returns The Unicode/UTF-32 representation of keysym, which is also
	 * compatible with UCS-4.  If the keysym does not have a Unicode
	 * representation, returns 0.
	 *
	 * This function does not perform any @ref keysym-transformations.
	 * Therefore, prefer to use state_key_get_utf32() if possible.
	 *
	 * @sa `state::state_key_get_utf32()`
	 */
	keysym_to_utf32 :: proc(keysym: keysym_t) -> i32 ---

	/**
	 * Get the keysym corresponding to a Unicode/UTF-32 codepoint.
	 *
	 * @returns The keysym corresponding to the specified Unicode
	 * codepoint, or XKB_KEY_NoSymbol if there is none.
	 *
	 * This function is the inverse of @ref keysym_to_utf32. In cases
	 * where a single codepoint corresponds to multiple keysyms, returns
	 * the keysym with the lowest value.
	 *
	 * Unicode codepoints which do not have a special (legacy) keysym
	 * encoding use a direct encoding scheme. These keysyms don’t usually
	 * have an associated keysym constant (`XKB_KEY_*`).
	 *
	 * @sa `keysym_to_utf32()`
	 * @since 1.0.0
	 * @since 1.9.0: Enable support for all noncharacters.
	 */
	utf32_to_keysym :: proc(ucs: i32) -> keysym_t ---

	/**
	 * Convert a keysym to its uppercase form.
	 *
	 * If there is no such form, the keysym is returned unchanged.
	 *
	 * The conversion rules are the *simple* (i.e. one-to-one) Unicode case
	 * mappings (with some exceptions, see hereinafter) and do not depend
	 * on the locale. If you need the special case mappings (i.e. not
	 * one-to-one or locale-dependent), prefer to work with the Unicode
	 * representation instead, when possible.
	 *
	 * Exceptions to the Unicode mappings:
	 *
	 * | Lower keysym | Lower letter | Upper keysym | Upper letter | Comment |
	 * | ------------ | ------------ | ------------ | ------------ | ------- |
	 * | `ssharp`     | `U+00DF`: ß  | `U1E9E`      | `U+1E9E`: ẞ  | [Council for German Orthography] |
	 *
	 * [Council for German Orthography]: https://www.rechtschreibrat.com/regeln-und-woerterverzeichnis/
	 *
	 * @since 0.8.0: Initial implementation, based on `libX11`.
	 * @since 1.8.0: Use Unicode 16.0 mappings for complete Unicode coverage.
	 * @since 1.12.0: Update to Unicode 17.0.
	 */
	keysym_to_upper :: proc(ks: keysym_t) -> keysym_t ---

	/**
	 * Convert a keysym to its lowercase form.
	 *
	 * If there is no such form, the keysym is returned unchanged.
	 *
	 * The conversion rules are the *simple* (i.e. one-to-one) Unicode case
	 * mappings and do not depend on the locale. If you need the special
	 * case mappings (i.e. not one-to-one or locale-dependent), prefer to
	 * work with the Unicode representation instead, when possible.
	 *
	 * @since 0.8.0: Initial implementation, based on `libX11`.
	 * @since 1.8.0: Use Unicode 16.0 mappings for complete Unicode coverage.
	 * @since 1.12.0: Update to Unicode 17.0.
	 */
	keysym_to_lower :: proc(ks: keysym_t) -> keysym_t ---
}

/** Flags for context creation. */
context_flags :: enum u32 {
	No_Flags             = 0,
	No_Default_includes  = 1,
	No_Environment_names = 2,
	No_Secure_getenv     = 4,
}

@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Create a new context.
	 *
	 * @param flags Optional flags for the context, or 0.
	 *
	 * @returns A new context, or `NULL` on failure.
	 *
	 * @memberof context
	 */
	context_new :: proc(flags: context_flags) -> ^ctx ---

	/**
	 * Take a new reference on a context.
	 *
	 * @returns The passed in context.
	 *
	 * @memberof context
	 */
	context_ref :: proc(_context: ^ctx) -> ^ctx ---

	/**
	 * Release a reference on a context, and possibly free it.
	 *
	 * @param context The context.  If it is `NULL`, this function does nothing.
	 *
	 * @memberof context
	 */
	context_unref :: proc(_context: ^ctx) ---

	/**
	 * Store custom user data in the context.
	 *
	 * This may be useful in conjunction with `context::context_set_log_fn()`
	 * or other callbacks.
	 *
	 * @memberof context
	 */
	context_set_user_data :: proc(_context: ^ctx, user_data: rawptr) ---

	/**
	 * Retrieves stored user data from the context.
	 *
	 * @returns The stored user data.  If the user data wasn’t set, or the
	 * passed in context is `NULL`, returns `NULL`.
	 *
	 * This may be useful to access private user data from callbacks like a
	 * custom logging function.
	 *
	 * @memberof context
	 **/
	context_get_user_data :: proc(_context: ^ctx) -> rawptr ---

	/**
	 * Append a new entry to the context’s include path.
	 *
	 * @returns 1 on success, or 0 if the include path could not be added or is
	 * inaccessible.
	 *
	 * @memberof context
	 */
	context_include_path_append :: proc(_context: ^ctx, path: cstring) -> i32 ---

	/**
	 * Append the default include paths to the context’s include path.
	 *
	 * @returns 1 on success, or 0 if the primary include path could not be added.
	 *
	 * @memberof context
	 */
	context_include_path_append_default :: proc(_context: ^ctx) -> i32 ---

	/**
	 * Reset the context’s include path to the default.
	 *
	 * Removes all entries from the context’s include path, and inserts the
	 * default paths.
	 *
	 * @returns 1 on success, or 0 if the primary include path could not be added.
	 *
	 * @memberof context
	 */
	context_include_path_reset_defaults :: proc(_context: ^ctx) -> i32 ---

	/**
	 * Remove all entries from the context’s include path.
	 *
	 * @memberof context
	 */
	context_include_path_clear :: proc(_context: ^ctx) ---

	/**
	 * Get the number of paths in the context’s include path.
	 *
	 * @memberof context
	 */
	context_num_include_paths :: proc(_context: ^ctx) -> u32 ---

	/**
	 * Get a specific include path from the context’s include path.
	 *
	 * @returns The include path at the specified index.  If the index is
	 * invalid, returns NULL.
	 *
	 * @memberof context
	 */
	context_include_path_get :: proc(_ctx: ^ctx, index: u32) -> cstring ---
}

/** Specifies a logging level. */
log_level :: enum u32 {
	Critical = 10,
	Error    = 20,
	Warning  = 30,
	Info     = 40,
	Debug    = 50,
}

@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Set the current logging level.
	 *
	 * @param context The context in which to set the logging level.
	 * @param level   The logging level to use.  Only messages from this level
	 * and below will be logged.
	 *
	 * The default level is `::XKB_LOG_LEVEL_ERROR`.  The environment variable
	 * `XKB_LOG_LEVEL`, if set in the time the context was created, overrides the
	 * default value.  It may be specified as a level number or name.
	 *
	 * @memberof context
	 */
	context_set_log_level :: proc(_context: ^ctx, level: log_level) ---

	/**
	 * Get the current logging level.
	 *
	 * @memberof context
	 */
	context_get_log_level :: proc(_context: ^ctx) -> log_level ---

	/**
	 * Sets the current logging verbosity.
	 *
	 * The library can generate a number of warnings which are not helpful to
	 * ordinary users of the library.  The verbosity may be increased if more
	 * information is desired (e.g. when developing a new keymap).
	 *
	 * The default verbosity is 0.  The environment variable `XKB_LOG_VERBOSITY`,
	 * if set in the time the context was created, overrides the default value.
	 *
	 * @param context   The context in which to use the set verbosity.
	 * @param verbosity The verbosity to use.  Currently used values are
	 * 1 to 10, higher values being more verbose.  0 would result in no verbose
	 * messages being logged.
	 *
	 * Most verbose messages are of level `::XKB_LOG_LEVEL_WARNING` or lower.
	 *
	 * @memberof context
	 */
	context_set_log_verbosity :: proc(_context: ^ctx, verbosity: i32) ---

	/**
	 * Get the current logging verbosity of the context.
	 *
	 * @memberof context
	 */
	context_get_log_verbosity :: proc(_context: ^ctx) -> i32 ---

	/**
	 * Set a custom function to handle logging messages.
	 *
	 * @param context The context in which to use the set logging function.
	 * @param log_fn  The function that will be called for logging messages.
	 * Passing `NULL` restores the default function, which logs to stderr.
	 *
	 * By default, log messages from this library are printed to stderr.  This
	 * function allows you to replace the default behavior with a custom
	 * handler.  The handler is only called with messages which match the
	 * current logging level and verbosity settings for the context.
	 * level is the logging level of the message.  @a format and @a args are
	 * the same as in the `vprintf(3)` function.
	 *
	 * You may use `context::context_set_user_data()` on the context, and
	 * then call `context::context_get_user_data()` from within the logging
	 * function to provide it with additional private context.
	 *
	 * @memberof context
	 */
	context_set_log_fn :: proc(_context: ^ctx, log_fn: ^proc(_: ^ctx, _: log_level, _: cstring, _: i32)) ---
}

/** Flags for keymap compilation. */
keymap_compile_flags :: enum u32 {
	No_Flags = 0,
}

/**
 * The possible keymap formats.
 *
 * See @ref keymap-text-format-v1-v2 "" for the complete description of the
 * formats and @ref keymap-support "" for detailed differences between the
 * formats.
 *
 * @remark A keymap can be parsed in one format and serialized in another,
 * thanks to automatic fallback mechanisms.
 *
 * <table>
 * <caption>
 * Keymap format to use depending on the target protocol
 * </caption>
 * <thead>
 * <tr>
 * <th colspan="2">Protocol</th>
 * <th colspan="2">libxkbcommon keymap format</th>
 * </tr>
 * <tr>
 * <th>Name</th>
 * <th>Keymap format</th>
 * <th>Parsing</th>
 * <th>Serialization</th>
 * </tr>
 * </thead>
 * <tbody>
 * <tr>
 * <th>X11</th>
 * <td>XKB</td>
 * <td>
 * `::XKB_KEYMAP_FORMAT_TEXT_V1`
 * </td>
 * <td>
 * *Always* use `::XKB_KEYMAP_FORMAT_TEXT_V1`, since the other formats are
 * incompatible.
 * </td>
 * </tr>
 * <tr>
 * <th>Wayland</th>
 * <td><code>[v1]</code></td>
 * <td>
 * <dl>
 * <dt>Wayland compositors<dt>
 * <dd>
 * The format depends on the keyboard layout database (usually [xkeyboard-config]).
 * Note that since v2 is a superset of v1, compositors are encouraged to use
 * `::XKB_KEYMAP_FORMAT_TEXT_V2` whenever possible.
 * </dd>
 * <dt>Client apps</dt>
 * <dd>
 * Clients should use `::XKB_KEYMAP_FORMAT_TEXT_V1` to parse the keymap sent
 * by a Wayland compositor, at least until `::XKB_KEYMAP_FORMAT_TEXT_V2`
 * stabilizes.
 * </dd>
 * </td>
 * <td>
 * At the time of writing (July 2025), the Wayland <code>[v1]</code> keymap
 * format is only defined as “libxkbcommon compatible”. In theory it enables
 * flexibility, but the set of supported features varies depending on the
 * libxkbcommon version and libxkbcommon keymap format used. Unfortunately there
 * is currently no Wayland API for keymap format *negotiation*.
 *
 * Therefore the **recommended** serialization format is
 * `::XKB_KEYMAP_FORMAT_TEXT_V1`, in order to ensure maximum compatibility for
 * interchange.
 *
 * Serializing using `::XKB_KEYMAP_FORMAT_TEXT_V2` should be considered
 * **experimental**, as some clients may fail to parse the resulting string.
 * </td>
 * </tr>
 * </tbody>
 * </table>
 *
 * [v1]: https://wayland.freedesktop.org/docs/html/apa.html#protocol-spec-wl_keyboard-enum-keymap_format
 * [xkeyboard-config]: https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config
 */
keymap_format :: enum u32 {
	Text_V1 = 1,
	Text_V2 = 2,
}

@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Create a keymap from a [RMLVO] builder.
	 *
	 * The primary keymap entry point: creates a new XKB keymap from a set of
	 * [RMLVO] \(Rules + Model + Layouts + Variants + Options) names.
	 *
	 * @param rmlvo   The [RMLVO] builder to use.  See `rmlvo_builder`.
	 * @param format  The text format of the keymap file to compile.
	 * @param flags   Optional flags for the keymap, or 0.
	 *
	 * @returns A keymap compiled according to the [RMLVO] names, or `NULL` if
	 * the compilation failed.
	 *
	 * @since 1.11.0
	 * @sa `keymap_new_from_names2()`
	 * @sa `rmlvo_builder`
	 * @memberof keymap
	 *
	 * [RMLVO]: @ref RMLVO-intro
	 */
	keymap_new_from_rmlvo :: proc(rmlvo: ^rmlvo_builder, format: keymap_format, flags: keymap_compile_flags) -> ^keymap ---

	/**
	 * Create a keymap from [RMLVO] names.
	 *
	 * Same as `keymap_new_from_names2()`, but with the keymap format fixed to:
	 * `::XKB_KEYMAP_FORMAT_TEXT_V2`.
	 *
	 * @deprecated Use `keymap_new_from_names2()` instead.
	 * @since 1.11.0: Deprecated
	 * @since 1.11.0: Use internally `::XKB_KEYMAP_FORMAT_TEXT_V2` instead of
	 * `::XKB_KEYMAP_FORMAT_TEXT_V1`
	 * @sa `keymap_new_from_names2()`
	 * @sa `rule_names`
	 * @sa `keymap_new_from_rmlvo()`
	 * @memberof keymap
	 *
	 * [RMLVO]: @ref RMLVO-intro
	 */
	keymap_new_from_names :: proc(_context: ^ctx, names: ^rule_names, flags: keymap_compile_flags) -> ^keymap ---

	/**
	 * Create a keymap from [RMLVO] names.
	 *
	 * The primary keymap entry point: creates a new XKB keymap from a set of
	 * [RMLVO] \(Rules + Model + Layouts + Variants + Options) names.
	 *
	 * @param context The context in which to create the keymap.
	 * @param names   The [RMLVO] names to use.  See rule_names.
	 * @param format  The text format of the keymap file to compile.
	 * @param flags   Optional flags for the keymap, or 0.
	 *
	 * @returns A keymap compiled according to the [RMLVO] names, or `NULL` if
	 * the compilation failed.
	 *
	 * @sa `rule_names`
	 * @sa `keymap_new_from_rmlvo()`
	 * @memberof keymap
	 * @since 1.11.0
	 *
	 * [RMLVO]: @ref RMLVO-intro
	 */
	keymap_new_from_names2 :: proc(_context: ^ctx, names: ^rule_names, format: keymap_format, flags: keymap_compile_flags) -> ^keymap ---

	/**
	 * Create a keymap from a keymap file.
	 *
	 * @param context The context in which to create the keymap.
	 * @param file    The keymap file to compile.
	 * @param format  The text format of the keymap file to compile.
	 * @param flags   Optional flags for the keymap, or 0.
	 *
	 * @returns A keymap compiled from the given XKB keymap file, or `NULL` if
	 * the compilation failed.
	 *
	 * The file must contain a complete keymap.  For example, in the
	 * `::XKB_KEYMAP_FORMAT_TEXT_V1` format, this means the file must contain one
	 * top level `%keymap` section, which in turn contains other required
	 * sections.
	 *
	 * @memberof keymap
	 */
	keymap_new_from_file :: proc(_context: ^ctx, file: ^i32, format: keymap_format, flags: keymap_compile_flags) -> ^keymap ---

	/**
	 * Create a keymap from a keymap string.
	 *
	 * This is just like `keymap_new_from_file()`, but instead of a file, gets
	 * the keymap as one enormous string.
	 *
	 * @see `keymap_new_from_file()`
	 * @memberof keymap
	 */
	keymap_new_from_string :: proc(_context: ^ctx, _string: cstring, format: keymap_format, flags: keymap_compile_flags) -> ^keymap ---

	/**
	 * Create a keymap from a memory buffer.
	 *
	 * This is just like `keymap_new_from_string()`, but takes a length argument
	 * so the input string does not have to be zero-terminated.
	 *
	 * @see `keymap_new_from_string()`
	 * @memberof keymap
	 * @since 0.3.0
	 */
	keymap_new_from_buffer :: proc(_context: ^ctx, buffer: cstring, length: i32, format: keymap_format, flags: keymap_compile_flags) -> ^keymap ---

	/**
	 * Take a new reference on a keymap.
	 *
	 * @returns The passed in keymap.
	 *
	 * @memberof keymap
	 */
	keymap_ref :: proc(_keymap: ^keymap) -> ^keymap ---

	/**
	 * Release a reference on a keymap, and possibly free it.
	 *
	 * @param keymap The keymap.  If it is `NULL`, this function does nothing.
	 *
	 * @memberof keymap
	 */
	keymap_unref :: proc(keymap: ^keymap) ---
}

/**
 * Flags to control keymap serialization.
 *
 * @since 1.12.0
 */
keymap_serialize_flags :: enum u32 {
	No_Flags    = 0,
	Pretty      = 1,
	Keep_Unused = 2,
}

@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Get the compiled keymap as a string.
	 *
	 * Same as `keymap::keymap_get_as_string2()` using
	 * `::XKB_KEYMAP_SERIALIZE_NO_FLAGS`.
	 *
	 * @since 1.12.0: Drop unused types and compatibility entries and do not
	 * pretty-print.
	 *
	 * @sa `keymap::keymap_get_as_string2()`
	 * @memberof keymap
	 */
	keymap_get_as_string :: proc(keymap: ^keymap, format: keymap_format) -> ^i8 ---

	/**
	 * Get the compiled keymap as a string.
	 *
	 * @param keymap The keymap to get as a string.
	 * @param format The keymap format to use for the string.  You can pass
	 * in the special value `::XKB_KEYMAP_USE_ORIGINAL_FORMAT` to use the format
	 * from which the keymap was originally created. When used as an *interchange*
	 * format such as Wayland <code>[v1]</code>, the format should be explicit.
	 * @param flags  Optional flags to control the serialization, or 0.
	 *
	 * @returns The keymap as a `NULL`-terminated string, or `NULL` if unsuccessful.
	 *
	 * The returned string may be fed back into `keymap_new_from_string()`
	 * to get the exact same keymap (possibly in another process, etc.).
	 *
	 * The returned string is *dynamically allocated* and should be freed by the
	 * caller.
	 *
	 * @since 1.12.0
	 *
	 * @sa `keymap_get_as_string()`
	 * @sa `keymap_new_from_string()`
	 * @memberof keymap
	 *
	 * [v1]: https://wayland.freedesktop.org/docs/html/apa.html#protocol-spec-wl_keyboard-enum-keymap_format
	 */
	keymap_get_as_string2 :: proc(keymap: ^keymap, format: keymap_format, flags: keymap_serialize_flags) -> ^i8 ---

	/**
	 * Get the minimum keycode in the keymap.
	 *
	 * @sa keycode_t
	 * @memberof keymap
	 * @since 0.3.1
	 */
	keymap_min_keycode :: proc(keymap: ^keymap) -> keycode_t ---

	/**
	 * Get the maximum keycode in the keymap.
	 *
	 * @sa keycode_t
	 * @memberof keymap
	 * @since 0.3.1
	 */
	keymap_max_keycode :: proc(keymap: ^keymap) -> keycode_t ---
}

/**
 * The iterator used by `keymap_key_for_each()`.
 *
 * @sa keymap_key_for_each
 * @memberof keymap
 * @since 0.3.1
 */
keymap_key_iter_t :: proc "c" (keymap: ^keymap, key: keycode_t, data: rawptr)

@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Run a specified function for every valid keycode in the keymap.  If a
	 * keymap is sparse, this function may be called fewer than
	 * (max_keycode - min_keycode + 1) times.
	 *
	 * @sa keymap_min_keycode()
	 * @sa keymap_max_keycode()
	 * @sa keycode_t
	 * @memberof keymap
	 * @since 0.3.1
	 */
	keymap_key_for_each :: proc(keymap: ^keymap, iter: keymap_key_iter_t, data: rawptr) ---

	/**
	 * Find the name of the key with the given keycode.
	 *
	 * This function always returns the canonical name of the key (see
	 * description in `keycode_t`).
	 *
	 * @returns The key name. If no key with this keycode exists,
	 * returns `NULL`.
	 *
	 * @sa keycode_t
	 * @memberof keymap
	 * @since 0.6.0
	 */
	keymap_key_get_name :: proc(keymap: ^keymap, key: keycode_t) -> cstring ---

	/**
	 * Find the keycode of the key with the given name.
	 *
	 * The name can be either a canonical name or an alias.
	 *
	 * @returns The keycode. If no key with this name exists,
	 * returns `::XKB_KEYCODE_INVALID`.
	 *
	 * @sa keycode_t
	 * @memberof keymap
	 * @since 0.6.0
	 */
	keymap_key_by_name :: proc(keymap: ^keymap, name: cstring) -> keycode_t ---

	/**
	 * Get the number of modifiers in the keymap.
	 *
	 * @sa mod_index_t
	 * @memberof keymap
	 */
	keymap_num_mods :: proc(keymap: ^keymap) -> mod_index_t ---

	/**
	 * Get the name of a modifier by index.
	 *
	 * @returns The name.  If the index is invalid, returns `NULL`.
	 *
	 * @sa mod_index_t
	 * @memberof keymap
	 */
	keymap_mod_get_name :: proc(keymap: ^keymap, idx: mod_index_t) -> cstring ---

	/**
	 * Get the index of a modifier by name.
	 *
	 * @returns The index.  If no modifier with this name exists, returns
	 * `xkb::MOD_INVALID`.
	 *
	 * @sa mod_index_t
	 * @memberof keymap
	 */
	keymap_mod_get_index :: proc(keymap: ^keymap, name: cstring) -> mod_index_t ---

	/**
	 * Get the encoding of a modifier by name.
	 *
	 * In X11 terminology it corresponds to the mapping to the *[real modifiers]*.
	 *
	 * @returns The encoding of a modifier.  Note that it may be 0 if the name does
	 * not exist or if the modifier is not mapped.
	 *
	 * @since 1.10.0
	 * @sa `keymap_mod_get_mask2()`
	 * @memberof keymap
	 *
	 * [real modifiers]: @ref real-modifier-def
	 */
	keymap_mod_get_mask :: proc(keymap: ^keymap, name: cstring) -> mod_mask_t ---

	/**
	 * Get the encoding of a modifier by index.
	 *
	 * In X11 terminology it corresponds to the mapping to the *[real modifiers]*.
	 *
	 * @returns The encoding of a modifier.  Note that it may be 0 if the modifier is
	 * not mapped.
	 *
	 * @since 1.11.0
	 * @sa `keymap_mod_get_mask()`
	 * @memberof keymap
	 *
	 * [real modifiers]: @ref real-modifier-def
	 */
	keymap_mod_get_mask2 :: proc(keymap: ^keymap, idx: mod_index_t) -> mod_mask_t ---

	/**
	 * Get the number of layouts in the keymap.
	 *
	 * @sa `layout_index_t`
	 * @sa `rule_names`
	 * @sa `keymap_num_layouts_for_key()`
	 * @memberof keymap
	 */
	keymap_num_layouts :: proc(keymap: ^keymap) -> layout_index_t ---

	/**
	 * Get the name of a layout by index.
	 *
	 * @returns The name.  If the index is invalid, or the layout does not have
	 * a name, returns `NULL`.
	 *
	 * @sa layout_index_t
	 *     For notes on layout names.
	 * @memberof keymap
	 */
	keymap_layout_get_name :: proc(keymap: ^keymap, idx: layout_index_t) -> cstring ---

	/**
	 * Get the index of a layout by name.
	 *
	 * @returns The index.  If no layout exists with this name, returns
	 * `::XKB_LAYOUT_INVALID`.  If more than one layout in the keymap has this name,
	 * returns the lowest index among them.
	 *
	 * @sa `layout_index_t` for notes on layout names.
	 * @memberof keymap
	 */
	keymap_layout_get_index :: proc(keymap: ^keymap, name: cstring) -> layout_index_t ---

	/**
	 * Get the number of LEDs in the keymap.
	 *
	 * @warning The range [ 0...`keymap_num_leds()` ) includes all of the LEDs
	 * in the keymap, but may also contain inactive LEDs.  When iterating over
	 * this range, you need the handle this case when calling functions such as
	 * `keymap_led_get_name()` or `state::state_led_index_is_active()`.
	 *
	 * @sa led_index_t
	 * @memberof keymap
	 */
	keymap_num_leds :: proc(keymap: ^keymap) -> led_index_t ---

	/**
	 * Get the name of a LED by index.
	 *
	 * @returns The name.  If the index is invalid, returns `NULL`.
	 *
	 * @memberof keymap
	 */
	keymap_led_get_name :: proc(keymap: ^keymap, idx: led_index_t) -> cstring ---

	/**
	 * Get the index of a LED by name.
	 *
	 * @returns The index.  If no LED with this name exists, returns
	 * `::XKB_LED_INVALID`.
	 *
	 * @memberof keymap
	 */
	keymap_led_get_index :: proc(keymap: ^keymap, name: cstring) -> led_index_t ---

	/**
	 * Get the number of layouts for a specific key.
	 *
	 * This number can be different from `keymap_num_layouts()`, but is always
	 * smaller.  It is the appropriate value to use when iterating over the
	 * layouts of a key.
	 *
	 * @sa layout_index_t
	 * @memberof keymap
	 */
	keymap_num_layouts_for_key :: proc(keymap: ^keymap, key: keycode_t) -> layout_index_t ---

	/**
	 * Get the number of shift levels for a specific key and layout.
	 *
	 * If @c layout is out of range for this key (that is, larger or equal to
	 * the value returned by `keymap_num_layouts_for_key()`), it is brought
	 * back into range in a manner consistent with
	 * `state::state_key_get_layout()`.
	 *
	 * @sa level_index_t
	 * @memberof keymap
	 */
	keymap_num_levels_for_key :: proc(keymap: ^keymap, key: keycode_t, layout: layout_index_t) -> level_index_t ---

	/**
	 * Retrieves every possible modifier mask that produces the specified
	 * shift level for a specific key and layout.
	 *
	 * This API is useful for inverse key transformation; i.e. finding out
	 * which modifiers need to be active in order to be able to type the
	 * keysym(s) corresponding to the specific key code, layout and level.
	 *
	 * @warning It returns only up to masks_size modifier masks. If the
	 * buffer passed is too small, some of the possible modifier combinations
	 * will not be returned.
	 *
	 * @param[in] keymap      The keymap.
	 * @param[in] key         The keycode of the key.
	 * @param[in] layout      The layout for which to get modifiers.
	 * @param[in] level       The shift level in the layout for which to get the
	 * modifiers. This should be smaller than:
	 * @code keymap_num_levels_for_key(keymap, key) @endcode
	 * @param[out] masks_out  A buffer in which the requested masks should be
	 * stored.
	 * @param[out] masks_size The number of elements in the buffer pointed to by
	 * masks_out.
	 *
	 * If @c layout is out of range for this key (that is, larger or equal to
	 * the value returned by `keymap_num_layouts_for_key()`), it is brought
	 * back into range in a manner consistent with
	 * `state::state_key_get_layout()`.
	 *
	 * @returns The number of modifier masks stored in the masks_out array.
	 * If the key is not in the keymap or if the specified shift level cannot
	 * be reached it returns 0 and does not modify the masks_out buffer.
	 *
	 * @sa level_index_t
	 * @sa mod_mask_t
	 * @memberof keymap
	 * @since 1.0.0
	 */
	keymap_key_get_mods_for_level :: proc(keymap: ^keymap, key: keycode_t, layout: layout_index_t, level: level_index_t, masks_out: ^mod_mask_t, masks_size: i32) -> i32 ---

	/**
	 * Get the keysyms obtained from pressing a key in a given layout and
	 * shift level.
	 *
	 * This function is like `state::state_key_get_syms()`, only the layout
	 * and shift level are not derived from the keyboard state but are instead
	 * specified explicitly.
	 *
	 * @param[in] keymap    The keymap.
	 * @param[in] key       The keycode of the key.
	 * @param[in] layout    The layout for which to get the keysyms.
	 * @param[in] level     The shift level in the layout for which to get the
	 * keysyms. This should be smaller than:
	 * @code keymap_num_levels_for_key(keymap, key) @endcode
	 * @param[out] syms_out An immutable array of keysyms corresponding to the
	 * key in the given layout and shift level.
	 *
	 * If @c layout is out of range for this key (that is, larger or equal to
	 * the value returned by `keymap_num_layouts_for_key()`), it is brought
	 * back into range in a manner consistent with
	 * `state::state_key_get_layout()`.
	 *
	 * @returns The number of keysyms in the syms_out array.  If no keysyms
	 * are produced by the key in the given layout and shift level, returns 0
	 * and sets @p syms_out to `NULL`.
	 *
	 * @sa `state::state_key_get_syms()`
	 * @memberof keymap
	 */
	keymap_key_get_syms_by_level :: proc(keymap: ^keymap, key: keycode_t, layout: layout_index_t, level: level_index_t, syms_out: ^^keysym_t) -> i32 ---

	/**
	 * Determine whether a key should repeat or not.
	 *
	 * A keymap may specify different repeat behaviors for different keys.
	 * Most keys should generally exhibit repeat behavior; for example, holding
	 * the `a` key down in a text editor should normally insert a single ‘a’
	 * character every few milliseconds, until the key is released.  However,
	 * there are keys which should not or do not need to be repeated.  For
	 * example, repeating modifier keys such as Left/Right Shift or Caps Lock
	 * is not generally useful or desired.
	 *
	 * @returns 1 if the key should repeat, 0 otherwise.
	 *
	 * @memberof keymap
	 */
	keymap_key_repeats :: proc(keymap: ^keymap, key: keycode_t) -> i32 ---

	/**
	 * Create a new keyboard state object.
	 *
	 * @param keymap The keymap which the state will use.
	 *
	 * @returns A new keyboard state object, or `NULL` on failure.
	 *
	 * @memberof state
	 */
	state_new :: proc(keymap: ^keymap) -> ^state ---

	/**
	 * Take a new reference on a keyboard state object.
	 *
	 * @returns The passed in object.
	 *
	 * @memberof state
	 */
	state_ref :: proc(_state: ^state) -> ^state ---

	/**
	 * Release a reference on a keyboard state object, and possibly free it.
	 *
	 * @param state The state.  If it is `NULL`, this function does nothing.
	 *
	 * @memberof state
	 */
	state_unref :: proc(state: ^state) ---

	/**
	 * Get the keymap which a keyboard state object is using.
	 *
	 * @returns The keymap which was passed to `state_new()` when creating
	 * this state object.
	 *
	 * This function does not take a new reference on the keymap; you must
	 * explicitly reference it yourself if you plan to use it beyond the
	 * lifetime of the state.
	 *
	 * @memberof state
	 */
	state_get_keymap :: proc(state: ^state) -> ^keymap ---
}

/** Specifies the direction of the key (press / release). */
key_direction :: enum u32 {
	Up   = 0,
	Down = 1,
}

/**
 * Modifier and layout types for state objects.  This enum is bitmaskable,
 * e.g. (`::XKB_STATE_MODS_DEPRESSED` | `::XKB_STATE_MODS_LATCHED`) is valid to
 * exclude locked modifiers.
 *
 * In XKB, the `DEPRESSED` components are also known as *base*.
 */
state_component :: enum u32 {
	Mods_Depressed   = 1,
	Mods_Latched     = 2,
	Mods_Locked      = 4,
	Mods_Effective   = 8,
	Layout_Depressed = 16,
	Layout_Latched   = 32,
	Layout_Locked    = 64,
	Layout_Effective = 128,
	Leds             = 256,
}

@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Update the keyboard state to reflect a given key being pressed or
	 * released.
	 *
	 * This entry point is intended for *server* applications and should not be used
	 * by *client* applications; see @ref server-client-state for details.
	 *
	 * A series of calls to this function should be consistent; that is, a call
	 * with `::XKB_KEY_DOWN` for a key should be matched by an `::XKB_KEY_UP`; if a
	 * key is pressed twice, it should be released twice; etc. Otherwise (e.g. due
	 * to missed input events), situations like “stuck modifiers” may occur.
	 *
	 * This function is often used in conjunction with the function
	 * `state_key_get_syms()` (or `state_key_get_one_sym()`), for example,
	 * when handling a key event.  In this case, you should prefer to get the
	 * keysyms *before* updating the key, such that the keysyms reported for
	 * the key event are not affected by the event itself.  This is the
	 * conventional behavior.
	 *
	 * @returns A mask of state components that have changed as a result of
	 * the update.  If nothing in the state has changed, returns 0.
	 *
	 * @memberof state
	 *
	 * @sa `state_update_mask()`
	 */
	state_update_key :: proc(state: ^state, key: keycode_t, direction: key_direction) -> state_component ---

	/**
	 * Update the keyboard state to change the latched and locked state of
	 * the modifiers and layout.
	 *
	 * This entry point is intended for *server* applications and should not be used
	 * by *client* applications; see @ref server-client-state for details.
	 *
	 * Use this function to update the latched and locked state according to
	 * “out of band” (non-device) inputs, such as UI layout switchers.
	 *
	 * @par Layout out of range
	 * @parblock
	 *
	 * If the effective layout, after taking into account the depressed, latched and
	 * locked layout, is out of range (negative or greater than the maximum layout),
	 * it is brought into range. Currently, the layout is wrapped using integer
	 * modulus (with negative values wrapping from the end). The wrapping behavior
	 * may be made configurable in the future.
	 *
	 * @endparblock
	 *
	 * @param state The keyboard state object.
	 * @param affect_latched_mods
	 * @param latched_mods
	 *     Modifiers to set as latched or unlatched. Only modifiers in
	 *     @p affect_latched_mods are considered.
	 * @param affect_latched_layout
	 * @param latched_layout
	 *     Layout to latch. Only considered if @p affect_latched_layout is true.
	 *     Maybe be out of range (including negative) -- see note above.
	 * @param affect_locked_mods
	 * @param locked_mods
	 *     Modifiers to set as locked or unlocked. Only modifiers in
	 *     @p affect_locked_mods are considered.
	 * @param affect_locked_layout
	 * @param locked_layout
	 *     Layout to lock. Only considered if @p affect_locked_layout is true.
	 *     Maybe be out of range (including negative) -- see note above.
	 *
	 * @returns A mask of state components that have changed as a result of
	 * the update.  If nothing in the state has changed, returns 0.
	 *
	 * @memberof state
	 *
	 * @sa state_update_mask()
	 */
	state_update_latched_locked :: proc(state: ^state, affect_latched_mods: mod_mask_t, latched_mods: mod_mask_t, affect_latched_layout: i32, latched_layout: i32, affect_locked_mods: mod_mask_t, locked_mods: mod_mask_t, affect_locked_layout: i32, locked_layout: i32) -> state_component ---

	/**
	 * Update a keyboard state from a set of explicit masks.
	 *
	 * This entry point is intended for *client* applications; see @ref
	 * server-client-state for details. *Server* applications should use
	 * `state_update_key()` instead.
	 *
	 * All parameters must always be passed, or the resulting state may be
	 * incoherent.
	 *
	 * @warning The serialization is lossy and will not survive round trips; it must
	 * only be used to feed client state objects, and must not be used to update the
	 * server state.
	 *
	 * @returns A mask of state components that have changed as a result of
	 * the update.  If nothing in the state has changed, returns 0.
	 *
	 * @memberof state
	 *
	 * @sa `state_component`
	 * @sa `state_update_key()`
	 */
	state_update_mask :: proc(state: ^state, depressed_mods: mod_mask_t, latched_mods: mod_mask_t, locked_mods: mod_mask_t, depressed_layout: layout_index_t, latched_layout: layout_index_t, locked_layout: layout_index_t) -> state_component ---

	/**
	 * Get the keysyms obtained from pressing a particular key in a given
	 * keyboard state.
	 *
	 * Get the keysyms for a key according to the current active layout,
	 * modifiers and shift level for the key, as determined by a keyboard
	 * state.
	 *
	 * @param[in]  state    The keyboard state object.
	 * @param[in]  key      The keycode of the key.
	 * @param[out] syms_out An immutable array of keysyms corresponding the
	 * key in the given keyboard state.
	 *
	 * As an extension to XKB, this function can return more than one keysym.
	 * If you do not want to handle this case, you can use
	 * `state_key_get_one_sym()` for a simpler interface.
	 *
	 * @returns The number of keysyms in the syms_out array.  If no keysyms
	 * are produced by the key in the given keyboard state, returns 0 and sets
	 * syms_out to `NULL`.
	 *
	 * This function performs Capitalization @ref keysym-transformations.
	 *
	 * @memberof state
	 *
	 * @since 1.9.0 This function now performs @ref keysym-transformations.
	 */
	state_key_get_syms :: proc(state: ^state, key: keycode_t, syms_out: ^^keysym_t) -> i32 ---

	/**
	 * Get the Unicode/UTF-8 string obtained from pressing a particular key
	 * in a given keyboard state.
	 *
	 * @param[in]  state  The keyboard state object.
	 * @param[in]  key    The keycode of the key.
	 * @param[out] buffer A buffer to write the string into.
	 * @param[in]  size   Size of the buffer.
	 *
	 * @warning If the buffer passed is too small, the string is truncated
	 * (though still `NULL`-terminated).
	 *
	 * @returns The number of bytes required for the string, excluding the
	 * `NULL` byte.  If there is nothing to write, returns 0.
	 *
	 * You may check if truncation has occurred by comparing the return value
	 * with the size of @p buffer, similarly to the `snprintf(3)` function.
	 * You may safely pass `NULL` and 0 to @p buffer and @p size to find the
	 * required size (without the `NULL`-byte).
	 *
	 * This function performs Capitalization and Control @ref
	 * keysym-transformations.
	 *
	 * @memberof state
	 * @since 0.4.1
	 */
	state_key_get_utf8 :: proc(state: ^state, key: keycode_t, buffer: ^i8, size: i32) -> i32 ---

	/**
	 * Get the Unicode/UTF-32 codepoint obtained from pressing a particular
	 * key in a a given keyboard state.
	 *
	 * @returns The UTF-32 representation for the key, if it consists of only
	 * a single codepoint.  Otherwise, returns 0.
	 *
	 * This function performs Capitalization and Control @ref
	 * keysym-transformations.
	 *
	 * @memberof state
	 * @since 0.4.1
	 */
	state_key_get_utf32 :: proc(state: ^state, key: keycode_t) -> i32 ---

	/**
	 * Get the single keysym obtained from pressing a particular key in a
	 * given keyboard state.
	 *
	 * This function is similar to `state_key_get_syms()`, but intended
	 * for users which cannot or do not want to handle the case where
	 * multiple keysyms are returned (in which case this function is
	 * preferred).
	 *
	 * @returns The keysym.  If the key does not have exactly one keysym,
	 * returns `XKB_KEY_NoSymbol`.
	 *
	 * This function performs Capitalization @ref keysym-transformations.
	 *
	 * @sa state_key_get_syms()
	 * @memberof state
	 */
	state_key_get_one_sym :: proc(state: ^state, key: keycode_t) -> keysym_t ---

	/**
	 * Get the effective layout index for a key in a given keyboard state.
	 *
	 * @returns The layout index for the key in the given keyboard state.  If
	 * the given keycode is invalid, or if the key is not included in any
	 * layout at all, returns `::XKB_LAYOUT_INVALID`.
	 *
	 * @invariant If the returned layout is valid, the following always holds:
	 * @code
	 * state_key_get_layout(state, key) < keymap_num_layouts_for_key(keymap, key)
	 * @endcode
	 *
	 * @memberof state
	 */
	state_key_get_layout :: proc(state: ^state, key: keycode_t) -> layout_index_t ---

	/**
	 * Get the effective shift level for a key in a given keyboard state and
	 * layout.
	 *
	 * @param state The keyboard state.
	 * @param key The keycode of the key.
	 * @param layout The layout for which to get the shift level.  This must be
	 * smaller than:
	 * @code keymap_num_layouts_for_key(keymap, key) @endcode
	 * usually it would be:
	 * @code state_key_get_layout(state, key) @endcode
	 *
	 * @return The shift level index.  If the key or layout are invalid,
	 * returns `::XKB_LEVEL_INVALID`.
	 *
	 * @invariant If the returned level is valid, the following always holds:
	 * @code
	 * state_key_get_level(state, key, layout) < keymap_num_levels_for_key(keymap, key, layout)
	 * @endcode
	 *
	 * @memberof state
	 */
	state_key_get_level :: proc(state: ^state, key: keycode_t, layout: layout_index_t) -> level_index_t ---
}

/**
 * Match flags for `state::state_mod_indices_are_active()` and
 * `state::state_mod_names_are_active()`, specifying the conditions for a
 * successful match.  `::XKB_STATE_MATCH_NON_EXCLUSIVE` is bitmaskable with
 * the other modes.
 */
state_match :: enum u32 {
	Any           = 1,
	All           = 2,
	Non_Exclusive = 65536,
}

@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * The counterpart to `state::state_update_mask()` for modifiers, to be
	 * used on the server side of serialization.
	 *
	 * This entry point is intended for *server* applications; see @ref
	 * server-client-state for details. *Client* applications should use the
	 * `state_mod_*_is_active` API.
	 *
	 * @param state      The keyboard state.
	 * @param components A mask of the modifier state components to serialize.
	 * State components other than `XKB_STATE_MODS_*` are ignored.
	 * If `::XKB_STATE_MODS_EFFECTIVE` is included, all other state components are
	 * ignored.
	 *
	 * @returns A `mod_mask_t` representing the given components of the
	 * modifier state.
	 *
	 * @memberof state
	 */
	state_serialize_mods :: proc(state: ^state, components: state_component) -> mod_mask_t ---

	/**
	 * The counterpart to `state::state_update_mask()` for layouts, to be
	 * used on the server side of serialization.
	 *
	 * This entry point is intended for *server* applications; see @ref
	 * server-client-state for details. *Client* applications should use the
	 * state_layout_*_is_active API.
	 *
	 * @param state      The keyboard state.
	 * @param components A mask of the layout state components to serialize.
	 * State components other than `XKB_STATE_LAYOUT_*` are ignored.
	 * If `::XKB_STATE_LAYOUT_EFFECTIVE` is included, all other state components are
	 * ignored.
	 *
	 * @returns A layout index representing the given components of the
	 * layout state.
	 *
	 * @memberof state
	 */
	state_serialize_layout :: proc(state: ^state, components: state_component) -> layout_index_t ---

	/**
	 * Test whether a modifier is active in a given keyboard state by name.
	 *
	 * @warning For [virtual modifiers], this function may *overmatch* in case
	 * there are virtual modifiers with overlapping mappings to [real modifiers].
	 *
	 * @returns 1 if the modifier is active, 0 if it is not.  If the modifier
	 * name does not exist in the keymap, returns -1.
	 *
	 * @memberof state
	 *
	 * @since 0.1.0: Works only with *real* modifiers
	 * @since 1.8.0: Works also with *virtual* modifiers
	 *
	 * [virtual modifiers]: @ref virtual-modifier-def
	 * [real modifiers]: @ref real-modifier-def
	 */
	state_mod_name_is_active :: proc(state: ^state, name: cstring, type: state_component) -> i32 ---

	/**
	 * Test whether a set of modifiers are active in a given keyboard state by
	 * name.
	 *
	 * @warning For [virtual modifiers], this function may *overmatch* in case
	 * there are virtual modifiers with overlapping mappings to [real modifiers].
	 *
	 * @param state The keyboard state.
	 * @param type  The component of the state against which to match the
	 * given modifiers.
	 * @param match The manner by which to match the state against the
	 * given modifiers.
	 * @param ...   The set of of modifier names to test, terminated by a NULL
	 * argument (sentinel).
	 *
	 * @returns 1 if the modifiers are active, 0 if they are not.  If any of
	 * the modifier names do not exist in the keymap, returns -1.
	 *
	 * @memberof state
	 *
	 * @since 0.1.0: Works only with *real* modifiers
	 * @since 1.8.0: Works also with *virtual* modifiers
	 *
	 * [virtual modifiers]: @ref virtual-modifier-def
	 * [real modifiers]: @ref real-modifier-def
	 */
	state_mod_names_are_active :: proc(state: ^state, type: state_component, match: state_match, #c_vararg _: ..any) -> i32 ---

	/**
	 * Test whether a modifier is active in a given keyboard state by index.
	 *
	 * @warning For [virtual modifiers], this function may *overmatch* in case
	 * there are virtual modifiers with overlapping mappings to [real modifiers].
	 *
	 * @returns 1 if the modifier is active, 0 if it is not.  If the modifier
	 * index is invalid in the keymap, returns -1.
	 *
	 * @memberof state
	 *
	 * @since 0.1.0: Works only with *real* modifiers
	 * @since 1.8.0: Works also with *virtual* modifiers
	 *
	 * [virtual modifiers]: @ref virtual-modifier-def
	 * [real modifiers]: @ref real-modifier-def
	 */
	state_mod_index_is_active :: proc(state: ^state, idx: mod_index_t, type: state_component) -> i32 ---

	/**
	 * Test whether a set of modifiers are active in a given keyboard state by
	 * index.
	 *
	 * @warning For [virtual modifiers], this function may *overmatch* in case
	 * there are virtual modifiers with overlapping mappings to [real modifiers].
	 *
	 * @param state The keyboard state.
	 * @param type  The component of the state against which to match the
	 * given modifiers.
	 * @param match The manner by which to match the state against the
	 * given modifiers.
	 * @param ...   The set of of modifier indices to test, terminated by a
	 * `::XKB_MOD_INVALID` argument (sentinel).
	 *
	 * @returns 1 if the modifiers are active, 0 if they are not.  If any of
	 * the modifier indices are invalid in the keymap, returns -1.
	 *
	 * @memberof state
	 *
	 * @since 0.1.0: Works only with *real* modifiers
	 * @since 1.8.0: Works also with *virtual* modifiers
	 *
	 * [virtual modifiers]: @ref virtual-modifier-def
	 * [real modifiers]: @ref real-modifier-def
	 */
	state_mod_indices_are_active :: proc(state: ^state, type: state_component, match: state_match, #c_vararg _: ..any) -> i32 ---
}

/**
 * Consumed modifiers mode.
 *
 * There are several possible methods for deciding which modifiers are
 * consumed and which are not, each applicable for different systems or
 * situations. The mode selects the method to use.
 *
 * Keep in mind that in all methods, the keymap may decide to *preserve*
 * a modifier, meaning it is not reported as consumed even if it would
 * have otherwise.
 */
consumed_mode :: enum u32 {
	Xkb = 0,
	Gtk = 1,
}

@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Get the mask of modifiers consumed by translating a given key.
	 *
	 * @param state The keyboard state.
	 * @param key   The keycode of the key.
	 * @param mode  The consumed modifiers mode to use; see enum description.
	 *
	 * @returns a mask of the consumed [real modifiers] modifiers.
	 *
	 * @memberof state
	 * @since 0.7.0
	 *
	 * [real modifiers]: @ref real-modifier-def
	 */
	state_key_get_consumed_mods2 :: proc(state: ^state, key: keycode_t, mode: consumed_mode) -> mod_mask_t ---

	/**
	 * Same as `state_key_get_consumed_mods2()` with mode `::XKB_CONSUMED_MODE_XKB`.
	 *
	 * @memberof state
	 * @since 0.4.1
	 */
	state_key_get_consumed_mods :: proc(state: ^state, key: keycode_t) -> mod_mask_t ---

	/**
	 * Test whether a modifier is consumed by keyboard state translation for
	 * a key.
	 *
	 * @warning For [virtual modifiers], this function may *overmatch* in case
	 * there are virtual modifiers with overlapping mappings to [real modifiers].
	 *
	 * @param state The keyboard state.
	 * @param key   The keycode of the key.
	 * @param idx   The index of the modifier to check.
	 * @param mode  The consumed modifiers mode to use; see enum description.
	 *
	 * @returns 1 if the modifier is consumed, 0 if it is not.  If the modifier
	 * index is not valid in the keymap, returns -1.
	 *
	 * @sa state_mod_mask_remove_consumed()
	 * @sa state_key_get_consumed_mods()
	 * @memberof state
	 * @since 0.7.0: Works only with *real* modifiers
	 * @since 1.8.0: Works also with *virtual* modifiers
	 *
	 * [virtual modifiers]: @ref virtual-modifier-def
	 * [real modifiers]: @ref real-modifier-def
	 */
	state_mod_index_is_consumed2 :: proc(state: ^state, key: keycode_t, idx: mod_index_t, mode: consumed_mode) -> i32 ---

	/**
	 * Same as `state_mod_index_is_consumed2()` with mode `::XKB_CONSUMED_MOD_XKB`.
	 *
	 * @warning For [virtual modifiers], this function may *overmatch* in case
	 * there are virtual modifiers with overlapping mappings to [real modifiers].
	 *
	 * @memberof state
	 * @since 0.4.1: Works only with *real* modifiers
	 * @since 1.8.0: Works also with *virtual* modifiers
	 *
	 * [virtual modifiers]: @ref virtual-modifier-def
	 * [real modifiers]: @ref real-modifier-def
	 */
	state_mod_index_is_consumed :: proc(state: ^state, key: keycode_t, idx: mod_index_t) -> i32 ---

	/**
	 * Remove consumed modifiers from a modifier mask for a key.
	 *
	 * @deprecated Use `state_key_get_consumed_mods2()` instead.
	 *
	 * Takes the given modifier mask, and removes all modifiers which are
	 * consumed for that particular key (as in `state_mod_index_is_consumed()`).
	 *
	 * @returns a mask of [real modifiers] modifiers.
	 *
	 * @sa state_mod_index_is_consumed()
	 * @memberof state
	 * @since 0.5.0: Works only with *real* modifiers
	 * @since 1.8.0: Works also with *virtual* modifiers
	 *
	 * [real modifiers]: @ref real-modifier-def
	 */
	state_mod_mask_remove_consumed :: proc(state: ^state, key: keycode_t, mask: mod_mask_t) -> mod_mask_t ---

	/**
	 * Test whether a layout is active in a given keyboard state by name.
	 *
	 * @returns 1 if the layout is active, 0 if it is not.  If no layout with
	 * this name exists in the keymap, return -1.
	 *
	 * If multiple layouts in the keymap have this name, the one with the lowest
	 * index is tested.
	 *
	 * @sa layout_index_t
	 * @memberof state
	 */
	state_layout_name_is_active :: proc(state: ^state, name: cstring, type: state_component) -> i32 ---

	/**
	 * Test whether a layout is active in a given keyboard state by index.
	 *
	 * @returns 1 if the layout is active, 0 if it is not.  If the layout index
	 * is not valid in the keymap, returns -1.
	 *
	 * @sa layout_index_t
	 * @memberof state
	 */
	state_layout_index_is_active :: proc(state: ^state, idx: layout_index_t, type: state_component) -> i32 ---

	/**
	 * Test whether a LED is active in a given keyboard state by name.
	 *
	 * @returns 1 if the LED is active, 0 if it not.  If no LED with this name
	 * exists in the keymap, returns -1.
	 *
	 * @sa led_index_t
	 * @memberof state
	 */
	state_led_name_is_active :: proc(state: ^state, name: cstring) -> i32 ---

	/**
	 * Test whether a LED is active in a given keyboard state by index.
	 *
	 * @returns 1 if the LED is active, 0 if it not.  If the LED index is not
	 * valid in the keymap, returns -1.
	 *
	 * @sa led_index_t
	 * @memberof state
	 */
	state_led_index_is_active :: proc(state: ^state, idx: led_index_t) -> i32 ---
}

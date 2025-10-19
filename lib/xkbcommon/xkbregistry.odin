/*
 * Copyright © 2020 Red Hat, Inc.
 * SPDX-License-Identifier: MIT
 */
package xkbcommon

/**
 * @struct rxkb_context
 *
 * Opaque top level library context object.
 *
 * The context contains general library state, like include paths and parsed
 * data. Objects are created in a specific context, and multiple contexts
 * may coexist simultaneously. Objects from different contexts are
 * completely separated and do not share any memory or state.
 */
rxkb_context :: struct {}

/**
 * @struct rxkb_model
 *
 * Opaque struct representing an XKB model.
 */
rxkb_model :: struct {}

/**
 * @struct rxkb_layout
 *
 * Opaque struct representing an XKB layout, including an optional variant.
 * Where the variant is `NULL`, the layout is the base layout.
 *
 * For example, `us` is the base layout, `us(intl)` is the `intl` variant of the
 * layout `us`.
 */
rxkb_layout :: struct {}

/**
 * @struct rxkb_option_group
 *
 * Opaque struct representing an option group. Option groups divide the
 * individual options into logical groups. Their main purpose is to indicate
 * whether some options are mutually exclusive or not.
 */
rxkb_option_group :: struct {}

/**
 * @struct rxkb_option
 *
 * Opaque struct representing an XKB option. Options are grouped inside an @ref
 * rxkb_option_group.
 */
rxkb_option :: struct {}

/**
 *
 * @struct rxkb_iso639_code
 *
 * Opaque struct representing an ISO 639-3 code (e.g. `eng`, `fra`). There
 * is no guarantee that two identical ISO codes share the same struct. You
 * must not rely on the pointer value of this struct.
 *
 * See https://iso639-3.sil.org/code_tables/639/data for a list of codes.
 */
rxkb_iso639_code :: struct {}

/**
 *
 * @struct rxkb_iso3166_code
 *
 * Opaque struct representing an ISO 3166 Alpha 2 code (e.g. `US`, `FR`).
 * There is no guarantee that two identical ISO codes share the same struct.
 * You must not rely on the pointer value of this struct.
 *
 * See https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes for a list
 * of codes.
 */
rxkb_iso3166_code :: struct {}

/**
 * Describes the popularity of an item. Historically, some highly specialized or
 * experimental definitions are excluded from the default list and shipped in
 * separate files. If these extra definitions are loaded (see @ref
 * RXKB_CONTEXT_LOAD_EXOTIC_RULES), the popularity of the item is set
 * accordingly.
 *
 * If the exotic items are not loaded, all items will have the standard
 * popularity.
 */
rxkb_popularity :: enum u32 {
	Standard = 1,
	Exotic   = 2,
}

/**
 * Flags for context creation.
 */
rxkb_context_flags :: enum u32 {
	No_Flags            = 0,
	No_Default_Includes = 1,
	Load_Exotic_Rules   = 2,
	No_Secure_Getenv    = 4,
}

foreign import lib "system:xkbcommon"
@(default_calling_convention = "c")
@(link_prefix = "xkb_")
foreign lib {

	/**
	 * Create a new xkb registry context.
	 *
	 * The context has an initial refcount of 1. Use `rxkb_context_unref()` to
	 * release memory associated with this context.
	 *
	 * Creating a context does not parse the files yet, use
	 * `rxkb_context_parse()`.
	 *
	 * @param flags Flags affecting context behavior
	 * @return A new xkb registry context or `NULL` on failure
	 */
	rxkb_context_new :: proc(flags: rxkb_context_flags) -> ^rxkb_context ---
}

/** Specifies a logging level. */
rxkb_log_level :: enum u32 {
	Critical = 10,
	Error    = 20,
	Warning  = 30,
	Info     = 40,
	Debug    = 50,
}

@(default_calling_convention = "c")
foreign lib {

	/**
	 * Set the current logging level.
	 *
	 * @param ctx     The context in which to set the logging level.
	 * @param level   The logging level to use.  Only messages from this level
	 * and below will be logged.
	 *
	 * The default level is `::RXKB_LOG_LEVEL_ERROR`.  The environment variable
	 * `RXKB_LOG_LEVEL`, if set at the time the context was created, overrides the
	 * default value.  It may be specified as a level number or name.
	 */
	rxkb_context_set_log_level :: proc(ctx: ^rxkb_context, level: rxkb_log_level) ---

	/**
	 * Get the current logging level.
	 */
	rxkb_context_get_log_level :: proc(ctx: ^rxkb_context) -> rxkb_log_level ---

	/**
	 * Set a custom function to handle logging messages.
	 *
	 * @param ctx     The context in which to use the set logging function.
	 * @param log_fn  The function that will be called for logging messages.
	 * Passing `NULL` restores the default function, which logs to `stderr`.
	 *
	 * By default, log messages from this library are printed to stderr.  This
	 * function allows you to replace the default behavior with a custom
	 * handler.  The handler is only called with messages which match the
	 * current logging level and verbosity settings for the context.
	 * level is the logging level of the message.  @a format and @a args are
	 * the same as in the `vprintf(3)` function.
	 *
	 * You may use `rxkb_context_set_user_data()` on the context, and then call
	 * `rxkb_context_get_user_data()` from within the logging function to provide
	 * it with additional private context.
	 */
	rxkb_context_set_log_fn :: proc(ctx: ^rxkb_context, log_fn: ^proc(_: ^rxkb_context, _: rxkb_log_level, _: cstring, _: i32)) ---

	/**
	 * Parse the given ruleset. This can only be called once per context and once
	 * parsed the data in the context is considered constant and will never
	 * change.
	 *
	 * This function parses all files with the given ruleset name. See
	 * rxkb_context_include_path_append() for details.
	 *
	 * If this function returns false, libxkbregistry failed to parse the xml files.
	 * This is usually caused by invalid files on the host and should be debugged by
	 * the host’s administrator using external tools. Callers should reduce the
	 * include paths to known good paths and/or fall back to a default RMLVO set.
	 *
	 * If this function returns false, the context should be be considered dead and
	 * must be released with `rxkb_context_unref()`.
	 *
	 * @param ctx The xkb registry context
	 * @param ruleset The ruleset to parse, e.g. `evdev`
	 * @return `true` on success or `false` on failure
	 */
	rxkb_context_parse :: proc(ctx: ^rxkb_context, ruleset: cstring) -> i32 ---

	/**
	 * Parse the default ruleset as configured at build time. See
	 * `rxkb_context_parse()` for details.
	 */
	rxkb_context_parse_default_ruleset :: proc(ctx: ^rxkb_context) -> i32 ---

	/**
	 * Increases the refcount of this object by one and returns the object.
	 *
	 * @param ctx The xkb registry context
	 * @return The passed in object
	 */
	rxkb_context_ref :: proc(ctx: ^rxkb_context) -> ^rxkb_context ---

	/**
	 * Decreases the refcount of this object by one. Where the refcount of an
	 * object hits zero, associated resources will be freed.
	 *
	 * @param ctx The xkb registry context
	 * @return always `NULL`
	 */
	rxkb_context_unref :: proc(ctx: ^rxkb_context) -> ^rxkb_context ---

	/**
	 * Assign user-specific data. libxkbregistry will not look at or modify the
	 * data, it will merely return the same pointer in
	 * `rxkb_context_get_user_data()`.
	 *
	 * @param ctx The xkb registry context
	 * @param user_data User-specific data pointer
	 */
	rxkb_context_set_user_data :: proc(ctx: ^rxkb_context, user_data: rawptr) ---

	/**
	 * Return the pointer passed into `rxkb_context_get_user_data()`.
	 *
	 * @param ctx The xkb registry context
	 * @return User-specific data pointer
	 */
	rxkb_context_get_user_data :: proc(ctx: ^rxkb_context) -> rawptr ---

	/**
	 * Append a new entry to the context’s include path.
	 *
	 * The include path handling is optimized for the most common use-case: a set of
	 * system files that provide a complete set of MLVO and some
	 * custom MLVO provided by a user **in addition** to the system set.
	 *
	 * The include paths should be given so that the least complete path is
	 * specified first and the most complete path is appended last. For example:
	 *
	 * ```c
	 * ctx = rxkb_context_new(RXKB_CONTEXT_NO_DEFAULT_INCLUDES);
	 * rxkb_context_include_path_append(ctx, `/home/user/.config/xkb`);
	 * rxkb_context_include_path_append(ctx, `/usr/share/X11/xkb`);
	 * rxkb_context_parse(ctx, `evdev`);
	 * ```
	 *
	 * The above example reflects the default behavior unless @ref
	 * RXKB_CONTEXT_NO_DEFAULT_INCLUDES is provided.
	 *
	 * Loading of the files is in **reverse order**, i.e. the last path appended is
	 * loaded first - in this case the ``/usr/share/X11/xkb`` path.
	 * Any models, layouts, variants and options defined in the `evdev` ruleset
	 * are loaded into the context. Then, any RMLVO found in the `evdev` ruleset of
	 * the user’s path (``/home/user/.config/xkb`` in this example) are **appended**
	 * to the existing set.
	 *
	 * Note that data from previously loaded include paths is never overwritten,
	 * only appended to. It is not not possible to change the system-provided data,
	 * only to append new models, layouts, variants and options to it.
	 *
	 * In other words, to define a new variant of the `us` layout called `banana`,
	 * the following XML is sufficient.
	 *
	 * ```xml
	 * <xkbConfigRegistry version="1.1">
	 * <layoutList>
	 *   <layout>
	 *     <configItem>
	 *       <name>us</name>
	 *     </configItem>
	 *     <variantList>
	 *       <variant>
	 *         <configItem>
	 *          <name>banana</name>
	 *          <description>English (Banana)</description>
	 *        </configItem>
	 *      </variant>
	 *    </layout>
	 * </layoutList>
	 * </xkbConfigRegistry>
	 * ```
	 *
	 * The list of models, options and all other layouts (including `us` and its
	 * variants) is taken from the system files. The resulting list of layouts will
	 * thus have a `us` keyboard layout with the variant `banana` and all other
	 * system-provided variants (`dvorak`, `colemak`, `intl`, etc.)
	 *
	 * This function must be called before `rxkb_context_parse()` or
	 * `rxkb_context_parse_default_ruleset()`.
	 *
	 * @returns `true` on success, or `false` if the include path could not be added
	 * or is inaccessible.
	 */
	rxkb_context_include_path_append :: proc(ctx: ^rxkb_context, path: cstring) -> i32 ---

	/**
	 * Append the default include paths to the context’s include path.
	 * See `rxkb_context_include_path_append()` for details about the merge order.
	 *
	 * This function must be called before `rxkb_context_parse()` or
	 * `rxkb_context_parse_default_ruleset()`.
	 *
	 * @returns `true` on success, or `false` if the include path could not be added
	 * or is inaccessible.
	 */
	rxkb_context_include_path_append_default :: proc(ctx: ^rxkb_context) -> i32 ---

	/**
	 * Return the first model for this context. Use this to start iterating over
	 * the models, followed by calls to `rxkb_model_next()`. Models are not sorted.
	 *
	 * The refcount of the returned model is not increased. Use `rxkb_model_ref()`
	 * if you need to keep this struct outside the immediate scope.
	 *
	 * @return The first model in the model list.
	 */
	rxkb_model_first :: proc(ctx: ^rxkb_context) -> ^rxkb_model ---

	/**
	 * Return the next model for this context. Returns `NULL` when no more models
	 * are available.
	 *
	 * The refcount of the returned model is not increased. Use `rxkb_model_ref()`
	 * if you need to keep this struct outside the immediate scope.
	 *
	 * @return the next model or `NULL` at the end of the list
	 */
	rxkb_model_next :: proc(m: ^rxkb_model) -> ^rxkb_model ---

	/**
	 * Increase the refcount of the argument by one.
	 *
	 * @returns The argument passed in to this function.
	 */
	rxkb_model_ref :: proc(m: ^rxkb_model) -> ^rxkb_model ---

	/**
	 * Decrease the refcount of the argument by one. When the refcount hits zero,
	 * all memory associated with this struct is freed.
	 *
	 * @returns always `NULL`
	 */
	rxkb_model_unref :: proc(m: ^rxkb_model) -> ^rxkb_model ---

	/**
	 * Return the name of this model. This is the value for M in RMLVO, to be used
	 * with libxkbcommon.
	 */
	rxkb_model_get_name :: proc(m: ^rxkb_model) -> cstring ---

	/**
	 * Return a human-readable description of this model. This function may return
	 * `NULL`.
	 */
	rxkb_model_get_description :: proc(m: ^rxkb_model) -> cstring ---

	/**
	 * Return the vendor name for this model. This function may return `NULL`.
	 */
	rxkb_model_get_vendor :: proc(m: ^rxkb_model) -> cstring ---

	/**
	 * Return the popularity for this model.
	 */
	rxkb_model_get_popularity :: proc(m: ^rxkb_model) -> rxkb_popularity ---

	/**
	 * Return the first layout for this context. Use this to start iterating over
	 * the layouts, followed by calls to `rxkb_layout_next()`.
	 *
	 * @note Layouts are not sorted.
	 *
	 * The refcount of the returned layout is not increased.
	 * Use `rxkb_layout_ref()` if you need to keep this struct outside the immediate
	 * scope.
	 *
	 * @return The first layout in the layout list.
	 */
	rxkb_layout_first :: proc(ctx: ^rxkb_context) -> ^rxkb_layout ---

	/**
	 * Return the next layout for this context. Returns `NULL` when no more layouts
	 * are available.
	 *
	 * The refcount of the returned layout is not increased. Use `rxkb_layout_ref()`
	 * if you need to keep this struct outside the immediate scope.
	 *
	 * @return the next layout or `NULL` at the end of the list
	 */
	rxkb_layout_next :: proc(l: ^rxkb_layout) -> ^rxkb_layout ---

	/**
	 * Increase the refcount of the argument by one.
	 *
	 * @returns The argument passed in to this function.
	 */
	rxkb_layout_ref :: proc(l: ^rxkb_layout) -> ^rxkb_layout ---

	/**
	 * Decrease the refcount of the argument by one. When the refcount hits zero,
	 * all memory associated with this struct is freed.
	 *
	 * @returns always `NULL`
	 */
	rxkb_layout_unref :: proc(l: ^rxkb_layout) -> ^rxkb_layout ---

	/**
	 * Return the name of this layout. This is the value for L in RMLVO, to be used
	 * with libxkbcommon.
	 */
	rxkb_layout_get_name :: proc(l: ^rxkb_layout) -> cstring ---

	/**
	 * Return the variant of this layout. This is the value for V in RMLVO, to be
	 * used with libxkbcommon.
	 *
	 * A variant does not stand on its own, it always depends on the base layout.
	 * e.g. there may be multiple variants called `intl` but there is only one
	 * `us(intl)`.
	 *
	 * Where the variant is `NULL`, the layout is the base layout (e.g. `us`).
	 */
	rxkb_layout_get_variant :: proc(l: ^rxkb_layout) -> cstring ---

	/**
	 * Return a short (one-word) description of this layout. This function may
	 * return `NULL`.
	 */
	rxkb_layout_get_brief :: proc(l: ^rxkb_layout) -> cstring ---

	/**
	 * Return a human-readable description of this layout. This function may return
	 * `NULL`.
	 */
	rxkb_layout_get_description :: proc(l: ^rxkb_layout) -> cstring ---

	/**
	 * Return the popularity for this layout.
	 */
	rxkb_layout_get_popularity :: proc(l: ^rxkb_layout) -> rxkb_popularity ---

	/**
	 * Return the first option group for this context. Use this to start iterating
	 * over the option groups, followed by calls to `rxkb_option_group_next()`.
	 * Option groups are not sorted.
	 *
	 * The refcount of the returned option group is not increased. Use
	 * `rxkb_option_group_ref()` if you need to keep this struct outside the immediate
	 * scope.
	 *
	 * @return The first option group in the option group list.
	 */
	rxkb_option_group_first :: proc(ctx: ^rxkb_context) -> ^rxkb_option_group ---

	/**
	 * Return the next option group for this context. Returns `NULL` when no more
	 * option groups are available.
	 *
	 * The refcount of the returned option group is not increased. Use
	 * `rxkb_option_group_ref()` if you need to keep this struct outside the immediate
	 * scope.
	 *
	 * @return the next option group or `NULL` at the end of the list
	 */
	rxkb_option_group_next :: proc(g: ^rxkb_option_group) -> ^rxkb_option_group ---

	/**
	 * Increase the refcount of the argument by one.
	 *
	 * @returns The argument passed in to this function.
	 */
	rxkb_option_group_ref :: proc(g: ^rxkb_option_group) -> ^rxkb_option_group ---

	/**
	 * Decrease the refcount of the argument by one. When the refcount hits zero,
	 * all memory associated with this struct is freed.
	 *
	 * @returns always `NULL`
	 */
	rxkb_option_group_unref :: proc(g: ^rxkb_option_group) -> ^rxkb_option_group ---

	/**
	 * Return the name of this option group. This is **not** the value for O in
	 * RMLVO, the name can be used for internal sorting in the caller. This function
	 * may return `NULL`.
	 */
	rxkb_option_group_get_name :: proc(m: ^rxkb_option_group) -> cstring ---

	/**
	 * Return a human-readable description of this option group. This function may
	 * return `NULL`.
	 */
	rxkb_option_group_get_description :: proc(m: ^rxkb_option_group) -> cstring ---

	/**
	 * @return `true` if multiple options within this option group can be selected
	 *                simultaneously, `false` if all options within this option
	 *                group are mutually exclusive.
	 */
	rxkb_option_group_allows_multiple :: proc(g: ^rxkb_option_group) -> i32 ---

	/**
	 * Return the popularity for this option group.
	 */
	rxkb_option_group_get_popularity :: proc(g: ^rxkb_option_group) -> rxkb_popularity ---

	/**
	 * Return the first option for this option group. Use this to start iterating
	 * over the options, followed by calls to `rxkb_option_next()`. Options are not
	 * sorted.
	 *
	 * The refcount of the returned option is not increased. Use `rxkb_option_ref()`
	 * if you need to keep this struct outside the immediate scope.
	 *
	 * @return The first option in the option list.
	 */
	rxkb_option_first :: proc(group: ^rxkb_option_group) -> ^rxkb_option ---

	/**
	 * Return the next option for this option group. Returns `NULL` when no more
	 * options are available.
	 *
	 * The refcount of the returned options is not increased. Use `rxkb_option_ref()`
	 * if you need to keep this struct outside the immediate scope.
	 *
	 * @returns The next option or `NULL` at the end of the list
	 */
	rxkb_option_next :: proc(o: ^rxkb_option) -> ^rxkb_option ---

	/**
	 * Increase the refcount of the argument by one.
	 *
	 * @returns The argument passed in to this function.
	 */
	rxkb_option_ref :: proc(o: ^rxkb_option) -> ^rxkb_option ---

	/**
	 * Decrease the refcount of the argument by one. When the refcount hits zero,
	 * all memory associated with this struct is freed.
	 *
	 * @returns always `NULL`
	 */
	rxkb_option_unref :: proc(o: ^rxkb_option) -> ^rxkb_option ---

	/**
	 * Return the name of this option. This is the value for O in RMLVO, to be used
	 * with libxkbcommon.
	 */
	rxkb_option_get_name :: proc(o: ^rxkb_option) -> cstring ---

	/**
	 * Return a short (one-word) description of this option. This function may
	 * return `NULL`.
	 */
	rxkb_option_get_brief :: proc(o: ^rxkb_option) -> cstring ---

	/**
	 * Return a human-readable description of this option. This function may return
	 * `NULL`.
	 */
	rxkb_option_get_description :: proc(o: ^rxkb_option) -> cstring ---

	/**
	 * Return the popularity for this option.
	 */
	rxkb_option_get_popularity :: proc(o: ^rxkb_option) -> rxkb_popularity ---

	/**
	 * Return `true` if the given option accepts layout index specifiers to restrict
	 * its application to the corresponding layouts, `false` otherwise.
	 *
 * @sa `rmlvo_builder::rmlvo_builder_append_layout()`
 * @sa `rule_names::options`

	 */
	rxkb_option_is_layout_specific :: proc(o: ^rxkb_option) -> i32 ---

	/**
	 * Increase the refcount of the argument by one.
	 *
	 * @returns The argument passed in to this function.
	 */
	rxkb_iso639_code_ref :: proc(iso639: ^rxkb_iso639_code) -> ^rxkb_iso639_code ---

	/**
	 * Decrease the refcount of the argument by one. When the refcount hits zero,
	 * all memory associated with this struct is freed.
	 *
	 * @returns always `NULL`
	 */
	rxkb_iso639_code_unref :: proc(iso639: ^rxkb_iso639_code) -> ^rxkb_iso639_code ---

	/**
	 * Return the ISO 639-3 code for this code. E.g. `eng`, `fra`.
	 */
	rxkb_iso639_code_get_code :: proc(iso639: ^rxkb_iso639_code) -> cstring ---

	/**
	 * Return the first ISO 639 for this layout. Use this to start iterating over
	 * the codes, followed by calls to `rxkb_iso639_code_next()`. Codes are not
	 * sorted.
	 *
	 * The refcount of the returned code is not increased.
	 * Use `rxkb_iso639_code_ref()` if you need to keep this struct outside the
	 * immediate scope.
	 *
	 * @return The first code in the code list.
	 */
	rxkb_layout_get_iso639_first :: proc(layout: ^rxkb_layout) -> ^rxkb_iso639_code ---

	/**
	 * Return the next code in the list. Returns `NULL` when no more codes
	 * are available.
	 *
	 * The refcount of the returned codes is not increased.
	 * Use `rxkb_iso639_code_ref()` if you need to keep this struct outside the
	 * immediate scope.
	 *
	 * @returns The next code or `NULL` at the end of the list
	 */
	rxkb_iso639_code_next :: proc(iso639: ^rxkb_iso639_code) -> ^rxkb_iso639_code ---

	/**
	 * Increase the refcount of the argument by one.
	 *
	 * @returns The argument passed in to this function.
	 */
	rxkb_iso3166_code_ref :: proc(iso3166: ^rxkb_iso3166_code) -> ^rxkb_iso3166_code ---

	/**
	 * Decrease the refcount of the argument by one. When the refcount hits zero,
	 * all memory associated with this struct is freed.
	 *
	 * @returns always `NULL`
	 */
	rxkb_iso3166_code_unref :: proc(iso3166: ^rxkb_iso3166_code) -> ^rxkb_iso3166_code ---

	/**
	 * Return the ISO 3166 Alpha 2 code for this code (e.g. `US`, `FR`).
	 */
	rxkb_iso3166_code_get_code :: proc(iso3166: ^rxkb_iso3166_code) -> cstring ---

	/**
	 * Return the first ISO 3166 for this layout. Use this to start iterating over
	 * the codes, followed by calls to `rxkb_iso3166_code_next()`. Codes are not
	 * sorted.
	 *
	 * The refcount of the returned code is not increased. Use
	 * `rxkb_iso3166_code_ref()` if you need to keep this struct outside the immediate
	 * scope.
	 *
	 * @return The first code in the code list.
	 */
	rxkb_layout_get_iso3166_first :: proc(layout: ^rxkb_layout) -> ^rxkb_iso3166_code ---

	/**
	 * Return the next code in the list. Returns `NULL` when no more codes
	 * are available.
	 *
	 * The refcount of the returned codes is not increased. Use
	 * `rxkb_iso3166_code_ref()` if you need to keep this struct outside the immediate
	 * scope.
	 *
	 * @returns The next code or `NULL` at the end of the list
	 */
	rxkb_iso3166_code_next :: proc(iso3166: ^rxkb_iso3166_code) -> ^rxkb_iso3166_code ---
}

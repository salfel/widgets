package main

import "core:fmt"
import "core:os"

css_file :: #load("../test.css")

main :: proc() {
	token_stream, ok := parse_tokens(string(css_file))
	assert(ok, "Failed to parse tokens")
	defer token_stream_destroy(&token_stream)

	ast, err := parse_ast(token_stream)
	if err != .None {
		fmt.println("Failed to parse AST", err)
		return
	}

	fmt.println(ast.selectors)
}

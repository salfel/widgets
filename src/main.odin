package main

import "core:fmt"
import "core:os"

css_file :: #load("../test.css")

main :: proc() {
	token_stream, ok := parse_tokens(string(css_file))
	assert(ok, "Failed to parse tokens")
	defer token_stream_destroy(&token_stream)

	for token in token_stream.tokens {
		fmt.println(token)
	}
}

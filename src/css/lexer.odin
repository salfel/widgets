package css

import "core:fmt"
import "core:math"
import "core:mem/virtual"
import "core:strings"
import "core:testing"

Token_Type :: enum {
	Ident,
	Number,
	Dot,
	Hashtag,
	Brace_Open,
	Brace_Close,
	Paranthesis_Open,
	Paranthesis_Close,
	Colon,
	Semicolon,
	Comma,
	Percentage,
}

Token :: struct {
	type:  Token_Type,
	value: union {
		string,
		f32,
	},
}

Token_Stream :: struct {
	tokens: [dynamic]Token,
	arena:  virtual.Arena,
}

token_stream_destroy :: proc(token_stream: ^Token_Stream) {
	delete(token_stream.tokens)
	virtual.arena_free_all(&token_stream.arena)
}

is_identifier :: proc(char: u8) -> bool {
	return(
		char >= 'a' && char <= 'z' ||
		char >= 'A' && char <= 'Z' ||
		char == '_' ||
		char == '-' ||
		char >= '0' && char <= '9' \
	)
}

parse_tokens :: proc(contents: string) -> (token_stream: Token_Stream, err: Parser_Error) {
	context.allocator = virtual.arena_allocator(&token_stream.arena)

	for i := 0; i < len(contents); i += 1 {
		switch contents[i] {
		case '0' ..= '9':
			number: f32 = 0
			comma_offset := -1
			for ; i < len(contents); i += 1 {
				if contents[i] == '.' {
					comma_offset = i
					continue
				} else if contents[i] < '0' || contents[i] > '9' {
					break
				}

				if comma_offset == -1 {
					number *= 10
					number += f32(contents[i] - '0')
				} else {
					num := f32(contents[i] - '0')
					number += num * math.pow_f32(10, -f32(i - comma_offset))
				}
			}

			i -= 1

			append(&token_stream.tokens, Token{.Number, number})
		case 'a' ..= 'z', 'A' ..= 'Z':
			builder := strings.builder_make_none()
			for ; i < len(contents); i += 1 {
				if !is_identifier(contents[i]) {
					break
				}

				strings.write_byte(&builder, contents[i])
			}

			i -= 1

			append(&token_stream.tokens, Token{.Ident, strings.to_string(builder)})

		case '.':
			append(&token_stream.tokens, Token{.Dot, 0})
		case '#':
			append(&token_stream.tokens, Token{.Hashtag, 0})
		case '{':
			append(&token_stream.tokens, Token{.Brace_Open, 0})
		case '}':
			append(&token_stream.tokens, Token{.Brace_Close, 0})
		case '(':
			append(&token_stream.tokens, Token{.Paranthesis_Open, 0})
		case ')':
			append(&token_stream.tokens, Token{.Paranthesis_Close, 0})
		case ':':
			append(&token_stream.tokens, Token{.Colon, 0})
		case ';':
			append(&token_stream.tokens, Token{.Semicolon, 0})
		case ',':
			append(&token_stream.tokens, Token{.Comma, 0})
		case '%':
			append(&token_stream.tokens, Token{.Percentage, 0})
		case ' ', '\t', '\n', '\r':
			continue
		case:
			return {}, .Unexpected_Token
		}
	}

	return token_stream, nil
}

@(test)
test_parse_token :: proc(t: ^testing.T) {
	contents := ".class { width: 100.5; } #id { height: 100; } selector { test: 100; }"
	expected_tokens := []Token {
		Token{.Dot, nil},
		Token{.Ident, "class"},
		Token{.Brace_Open, nil},
		Token{.Ident, "width"},
		Token{.Colon, nil},
		Token{.Number, 100.5},
		Token{.Semicolon, nil},
		Token{.Brace_Close, nil},
		Token{.Hashtag, nil},
		Token{.Ident, "id"},
		Token{.Brace_Open, nil},
		Token{.Ident, "height"},
		Token{.Colon, nil},
		Token{.Number, 100},
		Token{.Semicolon, nil},
		Token{.Brace_Close, nil},
		Token{.Ident, "selector"},
		Token{.Brace_Open, nil},
		Token{.Ident, "test"},
		Token{.Colon, nil},
		Token{.Number, 100},
		Token{.Semicolon, nil},
		Token{.Brace_Close, nil},
	}

	token_stream, err := parse_tokens(contents)
	assert(err == .None, "Failed to parse tokens")

	defer token_stream_destroy(&token_stream)

	for i := 0; i < len(expected_tokens); i += 1 {
		assert(token_stream.tokens[i].type == expected_tokens[i].type, "Token type mismatch")
		assert(token_stream.tokens[i].value == expected_tokens[i].value, "Token value mismatch")
	}
}

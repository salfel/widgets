package css

import "core:fmt"
import "core:mem/virtual"
import "core:testing"

Ast :: struct {
	selectors: [dynamic]Rule,
	arena:     virtual.Arena,
}

ast_destroy :: proc(ast: ^Ast) {
	delete(ast.selectors)
	virtual.arena_free_all(&ast.arena)
}

Rule_Type :: enum {
	Element,
	Class,
	Id,
}

Rule :: struct {
	type:         Rule_Type,
	name:         string,
	declarations: map[Property]Value,
}

Property :: enum {
	Width,
	Height,
}

make_property :: proc(property: string) -> (Property, Parser_Error) {
	switch property {
	case "width":
		return Property.Width, nil
	case "height":
		return Property.Height, nil
	}

	return nil, .Unknown_Property
}

Value :: union {
	u32,
}

Parser_Error :: enum {
	None,
	Unexpected_Token,
	Unknown_Property,
}

parse_ast :: proc(token_stream: Token_Stream) -> (ast: Ast, err: Parser_Error) {
	context.allocator = virtual.arena_allocator(&ast.arena)

	for i := 0; i < len(token_stream.tokens); i += 1 {
		#partial switch token_stream.tokens[i].type {
		case Token_Type.Dot:
			i += 1
			name, declarations := parse_rule(token_stream.tokens[:], &i) or_return
			append(&ast.selectors, Rule{.Class, name, declarations})
		case Token_Type.Hashtag:
			i += 1
			name, declarations := parse_rule(token_stream.tokens[:], &i) or_return
			append(&ast.selectors, Rule{.Id, name, declarations})
		case Token_Type.Ident:
			name, declarations := parse_rule(token_stream.tokens[:], &i) or_return
			append(&ast.selectors, Rule{.Element, name, declarations})
		case:
			err = Parser_Error.Unexpected_Token
			return
		}
	}

	return
}

expect_token :: proc(token: Token, expected: Token_Type) -> (err: Parser_Error) {
	if token.type != expected {
		fmt.println("Expected token", expected, "but got", token.type)
		err = Parser_Error.Unexpected_Token
	}

	return
}

parse_declaration :: proc(tokens: []Token, i: ^int) -> (property: Property, value: Value, err: Parser_Error) {
	expect_token(tokens[i^], Token_Type.Ident) or_return
	property = make_property(tokens[i^].value.(string)) or_return
	i^ += 1

	expect_token(tokens[i^], Token_Type.Colon) or_return
	i^ += 1

	expect_token(tokens[i^], Token_Type.Number) or_return
	value = tokens[i^].value.(u32)
	i^ += 1

	expect_token(tokens[i^], Token_Type.Semicolon) or_return
	i^ += 1

	return
}

parse_rule :: proc(tokens: []Token, i: ^int) -> (name: string, declarations: map[Property]Value, err: Parser_Error) {
	expect_token(tokens[i^], Token_Type.Ident) or_return
	name = tokens[i^].value.(string)
	i^ += 1

	expect_token(tokens[i^], Token_Type.Brace_Open) or_return
	i^ += 1

	for i^ < len(tokens) {
		property, value := parse_declaration(tokens, &i^) or_return
		declarations[property] = value

		if tokens[i^].type == Token_Type.Brace_Close {
			break
		}
	}

	expect_token(tokens[i^], Token_Type.Brace_Close) or_return

	return
}

@(test)
test_parse_ast :: proc(t: ^testing.T) {
	contents := ".class { width: 100; height: 200; } #id { height: 100; }"

	token_stream, ok := parse_tokens(contents)
	testing.expect(t, ok, "Failed to parse tokens")
	defer token_stream_destroy(&token_stream)

	ast, err := parse_ast(token_stream)
	testing.expect(t, err == .None, "Failed to parse AST")
	defer ast_destroy(&ast)

	testing.expect(t, len(ast.selectors) == 2, "Failed to parse AST")
	testing.expect(t, ast.selectors[0].type == .Class, "Failed to parse AST")
	testing.expect(t, ast.selectors[0].name == "class", "Failed to parse AST")
	testing.expect(t, len(ast.selectors[0].declarations) == 2, "Failed to parse AST")
	testing.expect(t, ast.selectors[0].declarations[.Width] == 100, "Failed to parse AST")
	testing.expect(t, ast.selectors[0].declarations[.Height] == 200, "Failed to parse AST")
	testing.expect(t, ast.selectors[1].type == .Id, "Failed to parse AST")
	testing.expect(t, ast.selectors[1].name == "id", "Failed to parse AST")
	testing.expect(t, len(ast.selectors[1].declarations) == 1, "Failed to parse AST")
	testing.expect(t, ast.selectors[1].declarations[.Height] == 100, "Failed to parse AST")
}

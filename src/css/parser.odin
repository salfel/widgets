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
	Layout,
	Width,
	Height,
	Color,
	Padding_Left,
	Padding_Right,
	Padding_Top,
	Padding_Bottom,
	Margin_Left,
	Margin_Right,
	Margin_Top,
	Margin_Bottom,
	Border,
	Border_Radius,
}

Layout_Type :: enum {
	Block,
	Box,
}

Percentage :: distinct f32

Value :: union {
	Layout_Type,
	f32,
	Percentage,
	[3]f32,
	Border,
}

Border :: struct {
	color: [3]f32,
	width: f32,
}

Parser_Error :: enum {
	None,
	Unexpected_Token,
	Unknown_Property,
	Invalid_Value,
}

make_property :: proc(property: string) -> (Property, Parser_Error) {
	switch property {
	case "layout":
		return .Layout, nil
	case "width":
		return .Width, nil
	case "height":
		return .Height, nil
	case "color":
		return .Color, nil
	case "padding-left":
		return .Padding_Left, nil
	case "padding-right":
		return .Padding_Right, nil
	case "padding-top":
		return .Padding_Top, nil
	case "padding-bottom":
		return .Padding_Bottom, nil
	case "margin-left":
		return .Margin_Left, nil
	case "margin-right":
		return .Margin_Right, nil
	case "margin-top":
		return .Margin_Top, nil
	case "margin-bottom":
		return .Margin_Bottom, nil
	case "border":
		return .Border, nil
	case "border-radius":
		return .Border_Radius, nil
	}

	return nil, .Unknown_Property
}


parse :: proc(contents: string) -> (ast: Ast, err: Parser_Error) {
	token_stream := parse_tokens(contents) or_return
	ast, err = parse_ast(token_stream)

	return
}

parse_ast :: proc(token_stream: Token_Stream) -> (ast: Ast, err: Parser_Error) {
	ast.arena = token_stream.arena
	context.allocator = virtual.arena_allocator(&ast.arena)

	for i := 0; i < len(token_stream.tokens); i += 1 {
		#partial switch token_stream.tokens[i].type {
		case .Dot:
			i += 1
			name, declarations := parse_rule(token_stream.tokens[:], &i) or_return
			append(&ast.selectors, Rule{.Class, name, declarations})
		case .Hashtag:
			i += 1
			name, declarations := parse_rule(token_stream.tokens[:], &i) or_return
			append(&ast.selectors, Rule{.Id, name, declarations})
		case .Ident:
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
		fmt.eprintln("Expected token", expected, "but got", token.type)
		err = Parser_Error.Unexpected_Token
	}

	return
}

parse_rule :: proc(tokens: []Token, i: ^int) -> (name: string, declarations: map[Property]Value, err: Parser_Error) {
	expect_token(tokens[i^], .Ident) or_return
	name = tokens[i^].value.(string)
	i^ += 1

	expect_token(tokens[i^], .Brace_Open) or_return
	i^ += 1

	for i^ < len(tokens) {
		property, value := parse_declaration(tokens, &i^) or_return
		declarations[property] = value

		if tokens[i^].type == .Brace_Close {
			break
		}
	}

	expect_token(tokens[i^], .Brace_Close) or_return

	return
}

parse_declaration :: proc(tokens: []Token, i: ^int) -> (property: Property, value: Value, err: Parser_Error) {
	expect_token(tokens[i^], .Ident) or_return
	property = make_property(tokens[i^].value.(string)) or_return
	i^ += 1

	expect_token(tokens[i^], .Colon) or_return
	i^ += 1

	value = parse_value(tokens, &i^) or_return

	switch property {
	case .Layout:
		if _, ok := value.(Layout_Type); !ok {
			err = Parser_Error.Invalid_Value
			return
		}
	case .Color:
		if _, ok := value.([3]f32); !ok {
			err = Parser_Error.Invalid_Value
			return
		}
	case .Width,
	     .Height,
	     .Padding_Left,
	     .Padding_Right,
	     .Padding_Top,
	     .Padding_Bottom,
	     .Margin_Left,
	     .Margin_Right,
	     .Margin_Top,
	     .Margin_Bottom,
	     .Border_Radius:
		#partial switch v in value {
		case f32:
		case Percentage:
		case:
			err = Parser_Error.Invalid_Value
			return
		}
	case .Border:
		if _, ok := value.(Border); !ok {
			err = Parser_Error.Invalid_Value
			return
		}
	}

	expect_token(tokens[i^], .Semicolon) or_return
	i^ += 1

	return
}

parse_value :: proc(tokens: []Token, i: ^int) -> (value: Value, err: Parser_Error) {
	#partial switch tokens[i^].type {
	case .Number:
		value = parse_size(tokens, &i^) or_return

		if tokens[i^].type == .Comma {
			i^ += 1

			color := parse_color(tokens, &i^) or_return
			value = Border{color, value.(f32)}
		}
	case .Ident:
		ident := tokens[i^].value.(string)
		if ident == "rgb" {
			value = parse_color(tokens, &i^) or_return
		} else if ident == "box" {
			value = Layout_Type.Box
			i^ += 1
		} else if ident == "block" {
			value = Layout_Type.Block
			i^ += 1
		} else {
			err = Parser_Error.Unexpected_Token
		}
	case:
		err = Parser_Error.Unexpected_Token
	}

	return
}

parse_size :: proc(tokens: []Token, i: ^int) -> (size: Value, err: Parser_Error) {
	expect_token(tokens[i^], .Number) or_return
	size = tokens[i^].value.(f32)
	i^ += 1

	if tokens[i^].type == .Ident {
		if tokens[i^].value.(string) != "px" {
			err = Parser_Error.Invalid_Value
			return
		}

		i^ += 1
	} else if tokens[i^].type == .Percentage {
		size = Percentage(size.(f32) / 100)
		i^ += 1
	}

	return
}


parse_color :: proc(tokens: []Token, i: ^int) -> (color: [3]f32, err: Parser_Error) {
	expect_token(tokens[i^], .Ident) or_return
	if tokens[i^].value.(string) != "rgb" {
		err = Parser_Error.Invalid_Value
		return
	}
	i^ += 1

	expect_token(tokens[i^], .Paranthesis_Open) or_return
	i^ += 1

	for j := 0; j < 3; j += 1 {
		expect_token(tokens[i^], .Number) or_return
		color[j] = tokens[i^].value.(f32) / 255
		i^ += 1

		if j != 2 {
			expect_token(tokens[i^], .Comma) or_return
			i^ += 1
		}
	}

	expect_token(tokens[i^], .Paranthesis_Close) or_return
	i^ += 1

	return
}

@(test)
test_parse_ast :: proc(t: ^testing.T) {
	contents := ".class { width: 100px; height: 200.5; } #id { height: 100%; } element { color: rgb(255, 0, 0); border: 2px, rgb(255, 0, 0); border-radius: 10px; }"

	token_stream, err := parse_tokens(contents)
	testing.expect(t, err == .None)
	defer token_stream_destroy(&token_stream)

	ast: Ast
	ast, err = parse_ast(token_stream)
	testing.expect(t, err == .None)
	defer ast_destroy(&ast)

	testing.expect(t, len(ast.selectors) == 3)
	testing.expect(t, ast.selectors[0].type == .Class)
	testing.expect(t, ast.selectors[0].name == "class")
	testing.expect(t, len(ast.selectors[0].declarations) == 2)
	testing.expect(t, ast.selectors[0].declarations[.Width] == f32(100))
	testing.expect(t, ast.selectors[0].declarations[.Height] == f32(200.5))
	testing.expect(t, ast.selectors[1].type == .Id)
	testing.expect(t, ast.selectors[1].name == "id")
	testing.expect(t, len(ast.selectors[1].declarations) == 1)
	testing.expect(t, ast.selectors[1].declarations[.Height] == Percentage(1.0))
	testing.expect(t, ast.selectors[2].type == .Element)
	testing.expect(t, ast.selectors[2].name == "element")
	testing.expect(t, len(ast.selectors[2].declarations) == 3)
	testing.expect(t, ast.selectors[2].declarations[.Color] == [3]f32{1, 0, 0})
	testing.expect(t, ast.selectors[2].declarations[.Border_Radius] == f32(10))
}

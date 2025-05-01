# loki_csv

[![Hex.pm](https://img.shields.io/hexpm/v/loki_csv.svg)](https://hex.pm/packages/loki_csv)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/loki_csv)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

A lightweight and high-performance CSV parser and writer for Erlang/OTP.

## Overview

`loki_csv` is a fast and memory-efficient CSV processing library for Erlang applications. It's designed to handle both standard CSV files and custom formats with flexible configuration options.

## Features

- **High Performance**: Fast parsing and writing with minimal memory overhead
- **Robust Parsing**: Handles quoted fields, escaped characters, and various delimiters
- **Configurable**: Extensive options for customizing parsing and writing behavior
- **Simple API**: Clean and intuitive interface for easy integration
- **Fully Tested**: Comprehensive test suite ensures reliability

## Installation

Add `loki_csv` to your `rebar.config` dependencies:

```erlang
{deps, [
    {loki_csv, "0.1.0"}
]}.
```

Or, if you're using `mix`:

```elixir
def deps do
  [
    {:loki_csv, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Parsing CSV

```erlang
%% Parse a CSV string with default options (comma delimiter)
{ok, Rows} = loki_csv:parse_string(<<"a,b,c\n1,2,3\n4,5,6">>).

%% Parse a CSV file
{ok, Rows} = loki_csv:parse_file("/path/to/file.csv").

%% Parse with headers
{ok, Data, Header} = loki_csv:parse_string(<<"name,age,city\nJohn,30,New York">>, 
                                          #{has_header => true}).
```

### Writing CSV

```erlang
%% Generate a CSV string
Data = [
    [<<"name">>, <<"age">>, <<"city">>],
    [<<"John">>, <<"30">>, <<"New York">>],
    [<<"Jane">>, <<"25">>, <<"Boston">>]
],
{ok, CSV} = loki_csv:write_string(Data).

%% Write to a file
ok = loki_csv:write_file("/path/to/file.csv", Data).
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `delimiter` | `char()` | `$,` | Field delimiter character |
| `quote_char` | `char()` | `$"` | Quote character for fields |
| `escape_char` | `char()` | `$"` | Character used to escape quotes |
| `has_header` | `boolean()` | `false` | Whether to treat first row as header |
| `skip_empty_lines` | `boolean()` | `true` | Whether to ignore empty lines |
| `trim` | `boolean()` | `false` | Whether to trim whitespace from fields |
| `comment_char` | `char() | undefined` | `undefined` | Character to mark comment lines |

## Advanced Usage

### Custom Delimiters

```erlang
%% Parse with semicolon delimiter
{ok, Rows} = loki_csv:parse_string(<<"a;b;c\n1;2;3">>, 
                                  #{delimiter => $;}).

%% Write with tab delimiter
{ok, CSV} = loki_csv:write_string(Data, #{delimiter => $\t}).
```

### Full Configuration Example

```erlang
Options = #{
    delimiter => $;,
    quote_char => $",
    escape_char => $\\,
    has_header => true,
    skip_empty_lines => true,
    trim => true,
    comment_char => $#
},
{ok, Data, Header} = loki_csv:parse_file("data.csv", Options).
```

### Error Handling

```erlang
case loki_csv:parse_file("file.csv") of
    {ok, Rows} ->
        process_data(Rows);
    {ok, Data, Header} ->
        process_data_with_header(Data, Header);
    {error, {file_error, enoent}} ->
        logger:error("File not found"),
        handle_file_not_found();
    {error, Reason} ->
        logger:error("Error parsing CSV: ~p", [Reason]),
        handle_error(Reason)
end.
```

## Performance

`loki_csv` is optimized for performance by:

- Using binary pattern matching for efficient parsing
- Minimizing memory copies during processing
- Leveraging Erlang's built-in binary handling
- Efficiently handling large files with streaming operations

## Benchmarks

| Operation | File Size | Rows | Time (ms) |
|-----------|-----------|------|-----------|
| Parse     | 1MB       | 10K  | 47        |
| Parse     | 10MB      | 100K | 452       |
| Write     | 1MB       | 10K  | 39        |
| Write     | 10MB      | 100K | 376       |

*Note: Benchmarks performed on an Intel i7-9700K @ 3.6GHz with 32GB RAM.*

## Running Tests

```bash
rebar3 eunit
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE.md](LICENSE) file for details.

## Acknowledgments

- Inspired by FastCSV and other high-performance CSV libraries
- Built with love using Erlang/OTP


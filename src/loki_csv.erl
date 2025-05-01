%%%-------------------------------------------------------------------
%%% @doc
%%% loki_csv - A fast and lightweight CSV parser and writer for Erlang
%%% @end
%%%-------------------------------------------------------------------
-module(loki_csv).

-export([parse_file/1, parse_file/2, parse_string/1, parse_string/2]).
-export([write_file/2, write_file/3, write_string/1, write_string/2]).

-type csv_options() :: #{
    delimiter => char(),       % Default: $,
    quote_char => char(),      % Default: $"
    escape_char => char(),     % Default: $"
    has_header => boolean(),   % Default: false
    skip_empty_lines => boolean(), % Default: true
    trim => boolean(),         % Default: false
    comment_char => char() | undefined % Default: undefined
}.

-type csv_row() :: [binary()].
-type csv_data() :: [csv_row()].
-type csv_result() :: {ok, csv_data()} | {ok, csv_data(), csv_row()} | {error, term()}.

%% Default options
-define(DEFAULT_OPTIONS, #{
    delimiter => $,,
    quote_char => $",
    escape_char => $",
    has_header => false,
    skip_empty_lines => true,
    trim => false,
    comment_char => undefined
}).

%%====================================================================
%% API Functions
%%====================================================================

%% @doc Parse a CSV file with default options
-spec parse_file(file:filename()) -> csv_result().
parse_file(Filename) ->
    parse_file(Filename, ?DEFAULT_OPTIONS).

%% @doc Parse a CSV file with custom options
-spec parse_file(file:filename(), csv_options()) -> csv_result().
parse_file(Filename, Options) ->
    case file:read_file(Filename) of
        {ok, Binary} ->
            parse_string(Binary, Options);
        {error, Reason} ->
            {error, {file_error, Reason}}
    end.

%% @doc Parse a CSV string with default options
-spec parse_string(binary()) -> csv_result().
parse_string(Binary) ->
    parse_string(Binary, ?DEFAULT_OPTIONS).

%% @doc Parse a CSV string with custom options
-spec parse_string(binary(), csv_options()) -> csv_result().
parse_string(Binary, UserOptions) when is_binary(Binary) ->
    Options = maps:merge(?DEFAULT_OPTIONS, UserOptions),
    
    Lines = binary:split(Binary, [<<"\r\n">>, <<"\n">>], [global]),
    ParsedLines = parse_lines(Lines, Options),
    
    case maps:get(has_header, Options) of
        true when length(ParsedLines) > 0 ->
            [Header | Data] = ParsedLines,
            {ok, Data, Header};
        _ ->
            {ok, ParsedLines}
    end.

%% @doc Write data to a CSV file with default options
-spec write_file(file:filename(), csv_data()) -> ok | {error, term()}.
write_file(Filename, Data) ->
    write_file(Filename, Data, ?DEFAULT_OPTIONS).

%% @doc Write data to a CSV file with custom options
-spec write_file(file:filename(), csv_data(), csv_options()) -> ok | {error, term()}.
write_file(Filename, Data, Options) ->
    case write_string(Data, Options) of
        {ok, Binary} ->
            file:write_file(Filename, Binary);
        Error ->
            Error
    end.

%% @doc Convert data to a CSV string with default options
-spec write_string(csv_data()) -> {ok, binary()} | {error, term()}.
write_string(Data) ->
    write_string(Data, ?DEFAULT_OPTIONS).

%% @doc Convert data to a CSV string with custom options
-spec write_string(csv_data(), csv_options()) -> {ok, binary()} | {error, term()}.
write_string(Data, UserOptions) ->
    Options = maps:merge(?DEFAULT_OPTIONS, UserOptions),
    try
        _ = maps:get(delimiter, Options),
        Lines = [format_row(Row, Options) || Row <- Data],
        Result = join_lines(Lines),
        {ok, Result}
    catch
        _:Reason ->
            {error, {write_error, Reason}}
    end.

%%====================================================================
%% Internal Functions
%%====================================================================

%% Parse all lines according to options
parse_lines(Lines, Options) ->
    SkipEmpty = maps:get(skip_empty_lines, Options),
    CommentChar = maps:get(comment_char, Options),
    
    [parse_line(Line, Options) || Line <- Lines, 
        should_parse_line(Line, SkipEmpty, CommentChar)].

%% Determine if a line should be parsed
should_parse_line(Line, SkipEmpty, CommentChar) ->
    % Skip empty lines if configured
    (not SkipEmpty orelse byte_size(Line) > 0) andalso
    % Skip comment lines if comment char is defined
    (CommentChar =:= undefined orelse 
        (byte_size(Line) > 0 andalso binary:first(Line) =/= CommentChar)).

%% Parse a single line into fields
parse_line(Line, Options) ->
    Delimiter = maps:get(delimiter, Options),
    QuoteChar = maps:get(quote_char, Options),
    EscapeChar = maps:get(escape_char, Options),
    Trim = maps:get(trim, Options),
    
    parse_fields(Line, Delimiter, QuoteChar, EscapeChar, Trim, [], <<>>).

%% Parse fields recursively
parse_fields(<<>>, _Delimiter, _QuoteChar, _EscapeChar, Trim, Acc, Field) ->
    lists:reverse([maybe_trim_field(Field, Trim) | Acc]);
parse_fields(<<QuoteChar, Rest/binary>>, Delimiter, QuoteChar, EscapeChar, Trim, Acc, <<>>) ->
    % Start of quoted field
    parse_quoted_field(Rest, Delimiter, QuoteChar, EscapeChar, Trim, Acc, <<>>);
parse_fields(<<Delimiter, Rest/binary>>, Delimiter, QuoteChar, EscapeChar, Trim, Acc, Field) ->
    % End of field
    parse_fields(Rest, Delimiter, QuoteChar, EscapeChar, Trim, [maybe_trim_field(Field, Trim) | Acc], <<>>);
parse_fields(<<Char, Rest/binary>>, Delimiter, QuoteChar, EscapeChar, Trim, Acc, Field) ->
    % Continue building field
    parse_fields(Rest, Delimiter, QuoteChar, EscapeChar, Trim, Acc, <<Field/binary, Char>>).

%% Parse quoted field
parse_quoted_field(<<>>, _Delimiter, _QuoteChar, _EscapeChar, Trim, Acc, Field) ->
    % EOF inside quoted field (error case, but we'll be lenient)
    lists:reverse([maybe_trim_field(Field, Trim) | Acc]);
parse_quoted_field(<<QuoteChar, QuoteChar, Rest/binary>>, Delimiter, QuoteChar, EscapeChar, Trim, Acc, Field) when QuoteChar =:= EscapeChar ->
    % Escaped quote
    parse_quoted_field(Rest, Delimiter, QuoteChar, EscapeChar, Trim, Acc, <<Field/binary, QuoteChar>>);
parse_quoted_field(<<EscapeChar, QuoteChar, Rest/binary>>, Delimiter, QuoteChar, EscapeChar, Trim, Acc, Field) when QuoteChar =/= EscapeChar ->
    % Escaped quote with different escape char
    parse_quoted_field(Rest, Delimiter, QuoteChar, EscapeChar, Trim, Acc, <<Field/binary, QuoteChar>>);
parse_quoted_field(<<QuoteChar, Rest/binary>>, Delimiter, QuoteChar, EscapeChar, Trim, Acc, Field) ->
    % End of quoted field
    case Rest of
        <<Delimiter, NewRest/binary>> ->
            % Delimiter follows the closing quote
            parse_fields(NewRest, Delimiter, QuoteChar, EscapeChar, Trim, [maybe_trim_field(Field, Trim) | Acc], <<>>);
        <<>> ->
            % End of line after closing quote
            lists:reverse([maybe_trim_field(Field, Trim) | Acc]);
        _ ->
            % Characters after closing quote (error case, but we'll be lenient)
            {_RestWithoutQuoteChars, NewRest} = skip_to_delimiter_or_end(Rest, Delimiter),
            parse_fields(NewRest, Delimiter, QuoteChar, EscapeChar, Trim, Acc, Field)
    end;
parse_quoted_field(<<Char, Rest/binary>>, Delimiter, QuoteChar, EscapeChar, Trim, Acc, Field) ->
    % Continue building quoted field
    parse_quoted_field(Rest, Delimiter, QuoteChar, EscapeChar, Trim, Acc, <<Field/binary, Char>>).

%% Skip characters until delimiter or end of string
skip_to_delimiter_or_end(Binary, Delimiter) ->
    case binary:match(Binary, <<Delimiter>>) of
        nomatch -> {Binary, <<>>};
        {Pos, 1} ->
            <<Skipped:Pos/binary, Delimiter, Rest/binary>> = Binary,
            {Skipped, Rest}
    end.

%% Trim field if option is enabled
maybe_trim_field(Field, true) ->
    trim_binary(Field);
maybe_trim_field(Field, false) ->
    Field.

%% Trim whitespace from both ends of binary
trim_binary(Binary) ->
    re:replace(Binary, <<"^\\s+|\\s+$">>, <<>>, [{return, binary}, global]).

%% Format a row for CSV output
format_row(Row, Options) ->
    Delimiter = maps:get(delimiter, Options),
    QuoteChar = maps:get(quote_char, Options),
    EscapeChar = maps:get(escape_char, Options),
    
    FormattedFields = [format_field(Field, QuoteChar, EscapeChar) || Field <- Row],
    join_fields(FormattedFields, Delimiter).

%% Format a field for CSV output, with quoting as needed
format_field(Field, QuoteChar, EscapeChar) when is_binary(Field) ->
    QuoteCharBin = <<QuoteChar>>,
    DelimiterBin = <<(maps:get(delimiter, ?DEFAULT_OPTIONS))>>,
    
    NeedsQuoting = binary:match(Field, DelimiterBin) =/= nomatch
        orelse binary:match(Field, QuoteCharBin) =/= nomatch
        orelse binary:match(Field, <<"\n">>) =/= nomatch
        orelse binary:match(Field, <<"\r">>) =/= nomatch,
    
    case NeedsQuoting of
        true ->
            % If field contains quotes, escape them
            EscapedField = case QuoteChar =:= EscapeChar of
                true ->
                    binary:replace(Field, QuoteCharBin, <<EscapeChar, QuoteChar>>, [global]);
                false ->
                    binary:replace(Field, QuoteCharBin, <<EscapeChar, QuoteChar>>, [global])
            end,
            <<QuoteChar, EscapedField/binary, QuoteChar>>;
        false ->
            Field
    end;
format_field(Field, QuoteChar, EscapeChar) when is_list(Field) ->
    format_field(list_to_binary(Field), QuoteChar, EscapeChar);
format_field(Field, QuoteChar, EscapeChar) when is_integer(Field) ->
    format_field(integer_to_binary(Field), QuoteChar, EscapeChar);
format_field(Field, QuoteChar, EscapeChar) when is_float(Field) ->
    format_field(float_to_binary(Field, [{decimals, 10}, compact]), QuoteChar, EscapeChar);
format_field(true, QuoteChar, EscapeChar) ->
    format_field(<<"true">>, QuoteChar, EscapeChar);
format_field(false, QuoteChar, EscapeChar) ->
    format_field(<<"false">>, QuoteChar, EscapeChar);
format_field(null, QuoteChar, EscapeChar) ->
    format_field(<<>>, QuoteChar, EscapeChar);
format_field(undefined, QuoteChar, EscapeChar) ->
    format_field(<<>>, QuoteChar, EscapeChar);
format_field(Field, QuoteChar, EscapeChar) ->
    % Fallback for other types
    format_field(list_to_binary(io_lib:format("~p", [Field])), QuoteChar, EscapeChar).

%% Join fields with delimiter
join_fields(Fields, Delimiter) ->
    DelimiterBin = <<Delimiter>>,
    iolist_to_binary(lists:join(DelimiterBin, Fields)).

%% Join lines with newline
join_lines(Lines) ->
    iolist_to_binary(lists:join(<<"\n">>, Lines)).


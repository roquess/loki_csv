%%%-------------------------------------------------------------------
%%% @doc
%%% Unit tests for loki_csv module
%%% @end
%%%-------------------------------------------------------------------
-module(loki_csv_tests).

-include_lib("eunit/include/eunit.hrl").

%% Basic parsing test
parse_simple_test() ->
    CSV = <<"a,b,c\n1,2,3\n4,5,6">>,
    {ok, Result} = loki_csv:parse_string(CSV),
    ?assertEqual(3, length(Result)),
    ?assertEqual([<<"a">>, <<"b">>, <<"c">>], lists:nth(1, Result)),
    ?assertEqual([<<"1">>, <<"2">>, <<"3">>], lists:nth(2, Result)),
    ?assertEqual([<<"4">>, <<"5">>, <<"6">>], lists:nth(3, Result)).

%% Test with header
parse_with_header_test() ->
    CSV = <<"name,age,city\nJohn,30,New York\nJane,25,Boston">>,
    {ok, Data, Header} = loki_csv:parse_string(CSV, #{has_header => true}),
    ?assertEqual([<<"name">>, <<"age">>, <<"city">>], Header),
    ?assertEqual(2, length(Data)),
    ?assertEqual([<<"John">>, <<"30">>, <<"New York">>], lists:nth(1, Data)).

%% Test with custom delimiter
parse_with_delimiter_test() ->
    CSV = <<"a;b;c\n1;2;3">>,
    {ok, Result} = loki_csv:parse_string(CSV, #{delimiter => $;}),
    ?assertEqual(2, length(Result)),
    ?assertEqual([<<"a">>, <<"b">>, <<"c">>], lists:nth(1, Result)),
    ?assertEqual([<<"1">>, <<"2">>, <<"3">>], lists:nth(2, Result)).

%% Test with quoted fields
parse_quoted_fields_test() ->
    CSV = <<"\"a,b\",c,d\n1,\"2,3\",4">>,
    {ok, Result} = loki_csv:parse_string(CSV),
    ?assertEqual([<<"a,b">>, <<"c">>, <<"d">>], lists:nth(1, Result)),
    ?assertEqual([<<"1">>, <<"2,3">>, <<"4">>], lists:nth(2, Result)).

%% Test escaped quotes
parse_escaped_quotes_test() ->
    CSV = <<"\"a\"\"b\",c">>,
    {ok, Result} = loki_csv:parse_string(CSV),
    ?assertEqual([<<"a\"b">>, <<"c">>], lists:nth(1, Result)).

%% Test empty fields
parse_empty_fields_test() ->
    CSV = <<"a,,c\n,b,">>,
    {ok, Result} = loki_csv:parse_string(CSV),
    ?assertEqual([<<"a">>, <<>>, <<"c">>], lists:nth(1, Result)),
    ?assertEqual([<<>>, <<"b">>, <<>>], lists:nth(2, Result)).

%% Test skip empty lines
parse_skip_empty_lines_test() ->
    CSV = <<"a,b,c\n\n1,2,3\n\n">>,
    {ok, Result} = loki_csv:parse_string(CSV),
    ?assertEqual(2, length(Result)),
    {ok, Result2} = loki_csv:parse_string(CSV, #{skip_empty_lines => false}),
    ?assertEqual(5, length(Result2)).

%% Test trimming fields
parse_trim_fields_test() ->
    CSV = <<" a , b , c \n1 , 2 , 3 ">>,
    {ok, Result1} = loki_csv:parse_string(CSV),
    ?assertEqual([<<" a ">>, <<" b ">>, <<" c ">>], lists:nth(1, Result1)),
    {ok, Result2} = loki_csv:parse_string(CSV, #{trim => true}),
    ?assertEqual([<<"a">>, <<"b">>, <<"c">>], lists:nth(1, Result2)).

%% Test comments
parse_comments_test() ->
    CSV = <<"a,b,c\n#comment line\n1,2,3">>,
    {ok, Result1} = loki_csv:parse_string(CSV),
    ?assertEqual(3, length(Result1)),
    {ok, Result2} = loki_csv:parse_string(CSV, #{comment_char => $#}),
    ?assertEqual(2, length(Result2)).

%% Test writing CSV
write_simple_test() ->
    Data = [
        [<<"a">>, <<"b">>, <<"c">>],
        [<<"1">>, <<"2">>, <<"3">>]
    ],
    {ok, CSV} = loki_csv:write_string(Data),
    ?assertEqual(<<"a,b,c\n1,2,3">>, CSV).

%% Test writing with custom delimiter
write_with_delimiter_test() ->
    Data = [
        [<<"a">>, <<"b">>, <<"c">>],
        [<<"1">>, <<"2">>, <<"3">>]
    ],
    {ok, CSV} = loki_csv:write_string(Data, #{delimiter => $;}),
    ?assertEqual(<<"a;b;c\n1;2;3">>, CSV).

%% Test writing with quoting
write_with_quotes_test() ->
    Data = [
        [<<"a,b">>, <<"c">>],
        [<<"1">>, <<"2,3">>]
    ],
    {ok, CSV} = loki_csv:write_string(Data),
    ?assertEqual(<<"\"a,b\",c\n1,\"2,3\"">>, CSV).

%% Test writing with escaped quotes
write_escaped_quotes_test() ->
    Data = [
        [<<"a\"b">>, <<"c">>]
    ],
    {ok, CSV} = loki_csv:write_string(Data),
    ?assertEqual(<<"\"a\"\"b\",c">>, CSV).

%% Test round trip
round_trip_test() ->
    Original = [
        [<<"name">>, <<"age">>, <<"city">>],
        [<<"John \"Johnny\" Doe">>, <<"30">>, <<"New York, NY">>],
        [<<"Jane,Smith">>, <<"25">>, <<"Boston">>]
    ],
    {ok, CSV} = loki_csv:write_string(Original),
    {ok, Parsed} = loki_csv:parse_string(CSV),
    ?assertEqual(Original, Parsed).

%% Test file operations - these are integration tests that depend on file system
file_operations_test_() ->
    {setup,
     fun() -> test_file_path() end,
     fun(Path) -> file:delete(Path) end,
     fun(Path) ->
         [
             ?_test(begin
                 Data = [
                     [<<"a">>, <<"b">>, <<"c">>],
                     [<<"1">>, <<"2">>, <<"3">>]
                 ],
                 ok = loki_csv:write_file(Path, Data),
                 {ok, ReadData} = loki_csv:parse_file(Path),
                 ?assertEqual(Data, ReadData)
             end)
         ]
     end}.

%% Helper functions
test_file_path() ->
    "test_csv_file.csv".

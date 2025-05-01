%%%-------------------------------------------------------------------
%%% @doc loki_csv application
%%% @end
%%%-------------------------------------------------------------------
-module(loki_csv_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    loki_csv_sup:start_link().

stop(_State) ->
    ok.

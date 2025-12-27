%%%-------------------------------------------------------------------
%% @doc rico public API
%% @end
%%%-------------------------------------------------------------------

-module(rico_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    ok = rico_metrics:init(),
    rico_sup:start_link().

stop(_State) ->
    ok.

%% internal functions

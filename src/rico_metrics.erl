-module(rico_metrics).

-define(SPIRAL_TIME_SPAN, 16000).
-define(SPIRAL_OPTS, [{slot_period, 1000},
                      {time_span, ?SPIRAL_TIME_SPAN}]).

-define(BASE, rico).

%% API
-export([init/0, update/2, count/1, stat/0]).

-spec init() -> ok.
init() ->
  ok = exometer:ensure([?BASE, store, rate], counter, []),
  ok = exometer:ensure([?BASE, fetch, rate], counter, []),
  ok = exometer:ensure([?BASE, remove, rate], counter, []),
  ok = exometer:ensure([?BASE, store, time], spiral, ?SPIRAL_OPTS),
  ok = exometer:ensure([?BASE, fetch, time], spiral, ?SPIRAL_OPTS),
  ok = exometer:ensure([?BASE, remove, time], spiral, ?SPIRAL_OPTS).

-spec update([atom()], number()) -> ok.
update(Name, Value) ->
  ok = exometer:update([?BASE | Name], Value).

-spec count([atom()]) -> ok.
count(Name) ->
  update(Name, 1).

-spec stat() -> [{list(atom()), number()}].
stat() ->
  Items = [store, fetch, remove],
  lists:foldl(fun(Item, Acc) ->
      {ok, [{value, Count}]} = exometer:get_value([?BASE, Item, rate], value),
      {ok, [{one, Time}]} = exometer:get_value([?BASE, Item, time], one),
    [{[Item, rate], Count},
     {[Item, time], Time div (?SPIRAL_TIME_SPAN div 1000)}] ++ Acc
    end, [], Items).

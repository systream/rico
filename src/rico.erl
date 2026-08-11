%%%-------------------------------------------------------------------
%%% @author Peter Tihanyi
%%% @copyright (C) 2025, systream
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(rico).

-type bucket() :: binary().
-type key() :: binary().
-type data() :: binary().
-type pool() :: atom().

-type obj() :: riakc_obj:riakc_obj().

-export_type([bucket/0, key/0, data/0, obj/0, pool/0]).

%% API
-export([store/1, store/2,
         fetch/2, fetch/3,
         value/1, value/2,
         values/1,
         has_siblings/1,
         value_count/1,
         select_sibling/2,
         key/1,
         new_obj/3,
         store/3, store/4,
         remove/1, remove/2]).

-spec store(bucket(), key(), data()) -> {ok, obj()} | {error, term()}.
store(Bucket, Key, Data) ->
  store(default, Bucket, Key, Data).

-spec store(pool(), bucket(), key(), data()) -> {ok, obj()} | {error, term()}.
store(Pool, Bucket, Key, Data) ->
  case fetch(Pool, Bucket, Key) of
    {ok, Obj} ->
      store(Pool, value(Obj, Data));
    not_found ->
      store(Pool, new_obj(Bucket, Key, Data));
    Else ->
      Else
  end.

-spec store(obj()) -> {ok, obj()} | {error, term()}.
store(Obj) ->
  store(default, Obj).

-spec store(pool(), obj()) -> {ok, obj()} | {error, term()}.
store(Pool, Obj) ->
  measure(store, fun() -> execute(Pool, fun riakc_pb_socket:put/3, [Obj, [return_body]]) end).

-spec fetch(bucket(), key()) -> {ok, obj()} | not_found | {error, term()}.
fetch(Bucket, Key) ->
  fetch(default, Bucket, Key).

-spec fetch(pool(), bucket(), key()) -> {ok, obj()} | not_found | {error, term()}.
fetch(Pool, Bucket, Key) ->
  case measure(fetch, fun() -> execute(Pool, fun riakc_pb_socket:get/3, [Bucket, Key]) end) of
    {error, notfound} ->
      not_found;
    {error, notfound, _VC} ->
      not_found;
    Else ->
      Else
  end.

-spec remove(obj()) -> ok | {error, term()}.
remove(Obj) ->
  remove(default, Obj).

-spec remove(pool(), obj()) -> ok | {error, term()}.
remove(Pool, Obj) ->
  measure(remove, fun() -> execute(Pool, fun riakc_pb_socket:delete_obj/2, [Obj]) end).

-spec value(obj()) -> data().
value(Obj) ->
  riakc_obj:get_update_value(Obj).

-spec values(obj()) -> [data()].
values(Obj) ->
  riakc_obj:get_values(Obj).

-spec has_siblings(obj()) -> boolean().
has_siblings(Obj) ->
  value_count(Obj) > 1.

-spec value_count(obj()) -> non_neg_integer().
value_count(Obj) ->
  riakc_obj:value_count(Obj).

-spec select_sibling(obj(), pos_integer()) -> obj().
select_sibling(Obj, Index) ->
  riakc_obj:select_sibling(Index, Obj).

-spec key(obj()) -> key().
key(Obj) ->
  riakc_obj:key(Obj).

-spec value(obj(), data()) -> obj().
value(Obj, NewData) ->
  riakc_obj:update_value(Obj, NewData).

-spec new_obj(bucket(), key(), data()) -> obj().
new_obj(Bucket, Key, Value) ->
  riakc_obj:new(Bucket, Key, Value).

execute(Pool, Fun, Args) ->
  Pid = rico_pool:checkout(Pool),
  MaxRetry = application:get_env(rico, max_retry, 2),
  Result = retry_wrap(Pool, Fun, [Pid | Args], MaxRetry),
  rico_pool:checkin(Pool, Pid),
  Result.

retry_wrap(Pool, Fun, Args, MaxRetry) ->
  case apply(Fun, Args) of
    {error, disconnected} when MaxRetry >= 0 ->
      logger:warning("No connection to riak, retry"),
      [Pid | RemArgs] = Args,
      timer:sleep(3 + rand:uniform(7)),
      NewPid = rico_pool:checkout(Pool),
      rico_pool:checkin(Pool, Pid),
      retry_wrap(Pool, Fun, [NewPid | RemArgs], MaxRetry - 1);
    Else ->
      Else
  end.

measure(Name, Fun) ->
  {Time, Result} = timer:tc(Fun),
  rico_metrics:update([Name, time], Time),
  rico_metrics:count([Name, rate]),
  Result.
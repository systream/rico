%%%-------------------------------------------------------------------
%%% @author Peter Tihanyi
%%% @copyright (C) 2024, Systream
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(rico_SUITE).

%% API
-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Function: suite() -> Info
%% Info = [tuple()]
%%--------------------------------------------------------------------
suite() ->
  [{timetrap, {seconds, 30}}].

%%--------------------------------------------------------------------
%% Function: init_per_suite(Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%%--------------------------------------------------------------------
init_per_suite(Config) ->
  application:ensure_all_started(rico),
  Config.

%%--------------------------------------------------------------------
%% Function: end_per_suite(Config0) -> term() | {save_config,Config1}
%% Config0 = Config1 = [tuple()]
%%--------------------------------------------------------------------
end_per_suite(_Config) ->
  application:stop(rico),
  ok.

%%--------------------------------------------------------------------
%% Function: init_per_group(GroupName, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%%--------------------------------------------------------------------
init_per_group(_GroupName, Config) ->
  Config.

%%--------------------------------------------------------------------
%% Function: end_per_group(GroupName, Config0) ->
%%               term() | {save_config,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%%--------------------------------------------------------------------
end_per_group(_GroupName, _Config) ->
  ok.

%%--------------------------------------------------------------------
%% Function: init_per_testcase(TestCase, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% TestCase = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%%--------------------------------------------------------------------
init_per_testcase(_TestCase, Config) ->
  os:unsetenv("POOL_SIZE"),
  os:unsetenv("RIAK_PORT"),
  application:ensure_all_started(rico),
  Config.

%%--------------------------------------------------------------------
%% Function: end_per_testcase(TestCase, Config0) ->
%%               term() | {save_config,Config1} | {fail,Reason}
%% TestCase = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%%--------------------------------------------------------------------
end_per_testcase(_TestCase, _Config) ->
  ok.

%%--------------------------------------------------------------------
%% Function: groups() -> [Group]
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%% Shuffle = shuffle | {shuffle,{integer(),integer(),integer()}}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%              repeat_until_any_ok | repeat_until_any_fail
%% N = integer() | forever
%%--------------------------------------------------------------------
groups() ->
  [].

%%--------------------------------------------------------------------
%% Function: all() -> GroupsAndTestCases | {skip,Reason}
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%% TestCase = atom()
%% Reason = term()
%%--------------------------------------------------------------------
all() ->
  [ default_pool,
    default_pool_os_env,
    os_env_not_leak_to_non_default,
    store,
    disconnected,
    delete
  ].

%%--------------------------------------------------------------------
%% Function: TestCase(Config0) ->
%%               ok | exit() | {skip,Reason} | {comment,Comment} |
%%               {save_config,Config1} | {skip_and_save,Reason,Config1}
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% Comment = term()
%%--------------------------------------------------------------------
default_pool(_Config) ->
  application:stop(rico),
  PoolCfg = #{
    pool_size => 5,
    host => "localhost",
    port => "8087",
    user => "rico",
    pw => "ricopw",
    % certs can be {priv_dir, appname, file} | or absolute path like "/path/to/file"
    cacertfile => {priv_dir, rico, "rootCA.crt"},
    certfile => {priv_dir, rico, "rico.crt"},
    keyfile => {priv_dir, rico, "rico.key"}
  },
  application:set_env(rico, pools,  #{default => PoolCfg}),
  {ok, _} = application:ensure_all_started(rico),
  ?assertEqual({5, 0}, rico_pool:status(default)).

default_pool_os_env(_Config) ->
  application:stop(rico),
  os:putenv("POOL_SIZE", "1"),
  os:putenv("RIAK_PORT", "1111"),
  PoolCfg = #{
    pool_size => 5,
    host => "localhost",
    port => "8087",
    user => "rico",
    pw => "ricopw",
    cacertfile => {priv_dir, rico, "rootCA.crt"},
    certfile => "/tmp/cacert",
    keyfile => {priv_dir, rico, "rico.key"}
  },
  application:set_env(rico, pools,  #{default => PoolCfg}),
  {ok, _} = application:ensure_all_started(rico),
  ?assertEqual({1, 0}, rico_pool:status(default)),
  Pid = rico_pool:checkout(),
  RiakcPBSocketState = sys:get_state(Pid),
  ?assertEqual("localhost", element(2, RiakcPBSocketState)), % host
  ?assertEqual(1111, element(3, RiakcPBSocketState)), % port
  ?assertEqual(code:priv_dir(rico) ++ "/rootCA.crt", element(15, RiakcPBSocketState)), % root cert
  ?assertEqual("/tmp/cacert", element(16, RiakcPBSocketState)), % cacert.

  ?assertEqual({0, 1}, rico_pool:status(default)),
  rico_pool:checkin(Pid),
  ?assertEqual({1, 0}, rico_pool:status(default)).

os_env_not_leak_to_non_default(_Config) ->
  application:stop(rico),
  os:putenv("POOL_SIZE", "1"),
  os:putenv("RIAK_PORT", "1111"),
  PoolCfg = #{
    pool_size => 5,
    host => "localhost",
    port => "8087",
    user => "rico",
    pw => "ricopw",
    cacertfile => {priv_dir, rico, "rootCA.crt"},
    certfile => "/tmp/cacert",
    keyfile => {priv_dir, rico, "rico.key"}
  },
  application:set_env(rico, pools,  #{default => PoolCfg, non_default => PoolCfg}),
  {ok, _} = application:ensure_all_started(rico),
  ?assertEqual({5, 0}, rico_pool:status(non_default)),
  Pid = rico_pool:checkout(non_default),
  RiakcPBSocketState = sys:get_state(Pid),
  ?assertEqual(8087, element(3, RiakcPBSocketState)), % port.

  ?assertEqual({4, 1}, rico_pool:status(non_default)),
  rico_pool:checkin(non_default, Pid),
  ?assertEqual({5, 0}, rico_pool:status(non_default)).


store(_Config) ->
  application:stop(rico),
  meck:new(riakc_pb_socket, [passthrough]),
  meck:expect(riakc_pb_socket, start_link, fun(_, _, _) ->
                                             {ok, spawn_link(fun() -> timer:sleep(timer:seconds(30)) end)}
                                           end),
  PoolCfg = #{
    pool_size => 3,
    host => "localhost",
    port => "8087",
    user => "rico",
    pw => "ricopw",
    cacertfile => {priv_dir, rico, "rootCA.crt"},
    certfile => "/tmp/cacert",
    keyfile => {priv_dir, rico, "rico.key"}
  },
  application:set_env(rico, pools,  #{default => PoolCfg, test => PoolCfg}),
  {ok, _} = application:ensure_all_started(rico),

  Bucket = <<"bucket">>,
  Key = <<"foo">>,

  meck:expect(riakc_pb_socket, get, fun(_, _, _) -> {error, notfound, vector_clock} end),
  meck:expect(riakc_pb_socket, put, fun(_, Obj, _) -> {ok, Obj} end),

  % store
  ?assertEqual(not_found, rico:fetch(Bucket, Key)),
  ?assertEqual(not_found, rico:fetch(test, Bucket, Key)),

  meck:expect(riakc_pb_socket, get, fun(_, _, _) -> {error, notfound} end),
  ?assertEqual(not_found, rico:fetch(Bucket, Key)),
  ?assertEqual(not_found, rico:fetch(test, Bucket, Key)),

  {ok, Obj} = rico:store(Bucket, Key, <<"bar">>),
  ?assertEqual(<<"bar">>, rico:value(Obj)),

  % fetch and update
  meck:expect(riakc_pb_socket, get, fun(_, _, _) -> {ok, Obj} end),
  {ok, Obj2} = rico:store(Bucket, Key, <<"bar2">>),
  {ok, Obj3} = rico:store(test, Bucket, Key, <<"bar2">>),
  ?assertEqual(<<"bar2">>, rico:value(Obj2)),
  ?assertEqual(<<"bar2">>, rico:value(Obj3)),

  % store obj with default pool
  {ok, _} = rico:store(Obj2).

disconnected(_Config) ->
  application:stop(rico),
  meck:new(riakc_pb_socket, [passthrough]),
  meck:expect(riakc_pb_socket, start_link, fun(_, _, _) ->
    {ok, spawn_link(fun() -> timer:sleep(timer:seconds(30)) end)}
                                           end),
  PoolCfg = #{
    pool_size => 5,
    host => "localhost",
    port => "8087",
    user => "rico",
    pw => "ricopw",
    cacertfile => {priv_dir, rico, "rootCA.crt"},
    certfile => "/tmp/cacert",
    keyfile => {priv_dir, rico, "rico.key"}
  },
  application:set_env(rico, pools, #{default => PoolCfg, test => PoolCfg}),
  {ok, _} = application:ensure_all_started(rico),

  Bucket = <<"bucket2">>,
  Key = <<"foo2">>,

  meck:expect(riakc_pb_socket, get, fun(_, _, _) -> {error, disconnected} end),
  meck:expect(riakc_pb_socket, put, fun(_, _, _) -> {error, disconnected} end),
  meck:expect(riakc_pb_socket, delete_obj, fun(_, _) -> {error, disconnected} end),

  % store
  ?assertEqual({error, disconnected}, rico:fetch(Bucket, Key)),
  ?assertEqual({error, disconnected}, rico:store(Bucket, Key, <<"bar">>)),
  ?assertEqual({error, disconnected}, rico:remove(rico:new_obj(Bucket, Key, <<"bar">>))),

  ?assertEqual({error, disconnected}, rico:fetch(test, Bucket, Key)),
  ?assertEqual({error, disconnected}, rico:store(test, Bucket, Key, <<"bar">>)),
  ?assertEqual({error, disconnected}, rico:remove(test, rico:new_obj(Bucket, Key, <<"bar">>))).

delete(_Config) ->
  application:stop(rico),
  meck:new(riakc_pb_socket, [passthrough]),
  meck:expect(riakc_pb_socket, start_link, fun(_, _, _) ->
    {ok, spawn_link(fun() -> timer:sleep(timer:seconds(30)) end)}
                                           end),
  PoolCfg = #{
    pool_size => 1,
    host => "localhost",
    port => "8087",
    user => "rico",
    pw => "ricopw",
    cacertfile => {priv_dir, rico, "rootCA.crt"},
    certfile => "/tmp/cacert",
    keyfile => {priv_dir, rico, "rico.key"}
  },
  application:set_env(rico, pools, #{default => PoolCfg, test => PoolCfg}),
  {ok, _} = application:ensure_all_started(rico),

  Bucket = <<"bucket3">>,
  Key = <<"foo3">>,

  meck:expect(riakc_pb_socket, delete_obj, fun(_, _) -> ok end),
  % store
  ?assertEqual(ok, rico:remove(rico:new_obj(Bucket, Key, <<"bar">>))),
  ?assertEqual(ok, rico:remove(test, rico:new_obj(Bucket, Key, <<"bar">>))).
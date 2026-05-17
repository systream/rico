%%%-------------------------------------------------------------------
%%% @author Peter Tihanyi
%%% @copyright (C) 2025, systream
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(rico_pool).

-define(DEFAULT_POOL, default).
-define(DEFAULT_TIMEOUT, 5000).

%% API
-export([start_link/1, child_spec/1,
  checkout/0, checkout/1,
  checkin/1, checkin/2,
  pool_names/0,
  status/1]).

-spec child_spec(atom()) -> supervisor:child_spec().
child_spec(PoolName) ->
  PoolArgs = [{name, {local, PoolName}},
              {worker_module, ?MODULE},
              {size, get_pool_config_parameter(PoolName, pool_size)},
              {max_overflow, 0},
              {strategy, fifo}],
  poolboy:child_spec(PoolName, PoolArgs, [PoolName]).

-spec pool_names() -> [atom()].
pool_names() ->
  maps:keys(get_pools_config()).

-spec status(atom()) -> {Free :: integer(), InUse :: integer()}.
status(PoolName) ->
  {_StateName, Free, _Overflow, InUse} = poolboy:status(PoolName),
  {Free, InUse}.

-spec start_link([atom()]) -> {ok, pid()} | {error, term()}.
start_link([PoolName]) ->
  Host = get_pool_config_parameter(PoolName, host),
  Port = get_pool_config_parameter(PoolName, port),
  User = get_pool_config_parameter(PoolName, user),
  Pass = get_pool_config_parameter(PoolName, pw),
  logger:info("User ~p connecting to ~p on ~p", [User, Host, Port]),
  riakc_pb_socket:start_link(Host, Port,
                              [{auto_reconnect, true},
                               {keepalive, true},
                               {credentials, User, Pass},
                               {cacertfile, get_pool_config_parameter(PoolName, cacertfile)},
                               {certfile, get_pool_config_parameter(PoolName, certfile)},
                               {keyfile, get_pool_config_parameter(PoolName, keyfile)},
                               {ssl_opts, [
                                 {server_name_indication, Host},
                                 {customize_hostname_check, [
                                   {match_fun, public_key:pkix_verify_hostname_match_fun(https)}
                                 ]}
                               ]}
                             ]).


-spec checkout() -> pid().
checkout() ->
  checkout(?DEFAULT_POOL).

-spec checkout(atom()) -> pid().
checkout(PoolName) ->
  Timeout = application:get_env(rico, pool_checkout_timeout, ?DEFAULT_TIMEOUT),
  poolboy:checkout(PoolName, true, Timeout).

-spec checkin(pid()) -> ok.
checkin(Pid) ->
  checkin(?DEFAULT_POOL, Pid).

-spec checkin(atom(), pid()) -> ok.
checkin(PoolName, Pid) ->
  poolboy:checkin(PoolName, Pid).

-spec get_pools_config() -> map().
get_pools_config() ->
  {ok, Pools} = application:get_env(rico, pools),
  Pools.

-spec get_pool_config(atom()) -> map().
get_pool_config(Pool) ->
  maps:get(Pool, get_pools_config()).

-spec get_pool_config_parameter(atom(), atom()) -> term().
get_pool_config_parameter(?DEFAULT_POOL, Parameter) ->
  Default = maps:get(Parameter, get_pool_config(?DEFAULT_POOL)),
  maybe_convert(Parameter, get_os_parameter(Parameter, Default));
get_pool_config_parameter(PoolName, Parameter) ->
  maybe_convert(Parameter, maps:get(Parameter, get_pool_config(PoolName))).

-spec maybe_convert(atom(), string()) -> string() | integer().
maybe_convert(port, Value) when is_list(Value) ->
  list_to_integer(Value);
maybe_convert(pool_size, Value) when is_list(Value) ->
  list_to_integer(Value);
maybe_convert(Parameter, {priv_dir, APPName, FileName}) when Parameter =:= cacertfile orelse
                                                             Parameter =:= certfile orelse
                                                             Parameter =:= keyfile ->
  CertDir = code:priv_dir(APPName),
  filename:join([CertDir, FileName]);
maybe_convert(_Parameter, Value) ->
  Value.

-spec sys_config_to_os_env_map(atom()) -> list().
sys_config_to_os_env_map(host)        -> "RIAK_HOST";
sys_config_to_os_env_map(port)        -> "RIAK_PORT";
sys_config_to_os_env_map(user)        -> "RIAK_USER";
sys_config_to_os_env_map(pw)          -> "RIAK_PW";
sys_config_to_os_env_map(cacertfile)  -> "RIAK_CACERTFILE";
sys_config_to_os_env_map(certfile)    -> "RIAK_CERTFILE";
sys_config_to_os_env_map(keyfile)     -> "RIAK_KEYFILE";
sys_config_to_os_env_map(pool_size)   -> "POOL_SIZE".

-spec get_os_parameter(atom(), term()) -> term().
get_os_parameter(Parameter, DefaultValue) ->
  os:getenv(sys_config_to_os_env_map(Parameter),  DefaultValue).

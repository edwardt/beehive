-module (bh_test_util).
-author("Ari Lerner <arilerner@mac.com>").
-compile(export_all).

-ifndef(BHTEST).
-define (BHTEST, true).
-endif.

-include ("beehive.hrl").
-include ("common.hrl").

-export([display/1,display/2]).

setup() ->
  setup([]).

setup(Proplist) when is_list(Proplist) ->
  %% only run this setup if we don't have apps loaded
  case application:get_application(sasl) of
    undefined ->
      Dir = filename:dirname(filename:dirname(code:which(?MODULE))),
      ConfigFile = filename:join([Dir, "test", "fixtures", "beehive.cfg"]),
      display("Get test config ~p",[ConfigFile]),
      application:set_env(beehive, node_type,
                          proplists:get_value(node_type, Proplist, test_type)),
      display("NODE type ~p",[get_app_env(beehive, node_type)]),
      
      application:set_env(beehive, config_file,
                          proplists:get_value(config_file, Proplist, ConfigFile)),
      display("Config File ~p",[get_app_env(beehive, config_file)]),
      
      application:set_env(beehive, home,
                          proplists:get_value(home, Proplist,
                                              "/tmp/beehive/test")),
      display("Homedir ~p",[get_app_env(beehive, home)]),
      application:set_env(beehive, repository, "local_git"),

      display("Repository ~p",[get_app_env(beehive, repository)]),      
      application:set_env(beehive, database_dir,
                          proplists:get_value(database_dir, Proplist,
                                              "/tmp/beehive/test/test_db")),
      display("DBDir ~p",[get_app_env(beehive, database_dir)]),
      
      GlitterConfig = filename:join([Dir, "test", "gitolite-admin",
                                     "conf", "gitolite.conf"]),
      application:set_env(glitter, config_file, GlitterConfig),
      display("Got GLitter environemt config: ~p", [GlitterConfig]),
      
      application:start(sasl),      
      display("SASL started ~n"),
      
      %% We don't need any error output here.
      beehive:start([{beehive_db_srv, testing}]),
      display("Started DB server ~n"),
      
      inets:start(),
      display("Started Inets ~n");
      
    {ok, _} -> ok
  end;
setup(Table) ->
  setup(),
  clear_table(Table),
  ok.
  
get_app_env(App, Key) when is_atom(App), is_atom(Key)->
  {ok, Value} = application:get_env(App, Key),
  Value.

display(Message) when is_list(Message) ->
  error_logger:info_msg(Message).

display(Format, Message) when is_list(Format), is_list(Message) ->
  error_logger:info_msg(Format, Message).
  
check_named_proc(Name)-> 
  whereis(Name).

try_to_fetch_url_or_retry(_Method, _Args, 0) -> failed;
try_to_fetch_url_or_retry(Method, Args, Times) ->
  case bh_test_util:fetch_url(Method, Args) of
    {ok, _Headers, _Body} = T -> T;
    _E -> try_to_fetch_url_or_retry(Method, Args, Times - 1)
  end.

fetch_url(Method, Props) ->
  Host    = proplists:get_value(host, Props, "localhost"),
  Port    = proplists:get_value(port, Props, 4999),
  Path    = proplists:get_value(path, Props, "/"),

  Headers = proplists:get_value(headers, Props, []),

  Params  = lists:flatten(lists:map(fun({Key, Value}) ->
                                        lists:flatten([atom_to_list(Key),
                                                       "=", Value, "&"])
                                    end,
                                    proplists:get_value(params, Props, []))),
  case gen_tcp:connect(Host, Port, [binary]) of
    {ok, Sock} ->

      RequestLine =
        lists:flatten(
          [string:to_upper(atom_to_list(Method)),
           " ",
           Path,
           " HTTP/1.0\r\n",
           lists:map(fun({Key, Value}) ->
                         lists:flatten([Key, ": ", Value, "\n"])
                     end, Headers),
           lists:flatten(["Host: ", Host, ":", integer_to_list(Port), "\n"]),
           lists:flatten(["Content-Length: ", integer_to_list(erlang:length(Params))]),
           "\r\n\r\n",
           Params,
           "\r\n"]),
      gen_tcp:send(Sock, RequestLine),
      request(Sock, []);
    Else ->
      {error, Else}
  end.

request(Sock, Acc) ->
  receive
    {tcp, Sock, Data} ->
      %% Received data
      request(Sock, [binary_to_list(Data)|Acc]);
    {tcp_closed, Sock} ->
      parse_http_request(lists:flatten(lists:reverse(Acc)));
    {tcp_error, Sock} ->
      {error, Sock};
    Else ->
      erlang:display({got, Else}),
      request(Sock, Acc)
      %% If there is no activity for a while and the socket has not
      %% already closed, we'll assume that the connection is tired and
      %% should close, so we'll close it
  after 800 ->
      {error, timeout}
  end.

parse_http_request(Acc) ->
  [Headers|Body] = string:tokens(Acc, "\r\n"),
  {ok, Headers, Body}.

start(Count)      -> start(Count, example_cluster_srv, 0, []).
start(Count, Mod) -> start(Count, Mod, 0, []).
start(Count, _Mod, Count, Acc) -> {ok, Acc};
start(Count, Mod, CurrentCount, Acc) ->
  Name = erlang:list_to_atom(
           lists:flatten(["node", erlang:integer_to_list(CurrentCount)])),
  Seed = case erlang:length(Acc) of
           0 -> undefined;
           _ -> whereis(erlang:hd(Acc))
         end,
  {ok, _NodePid} = Mod:start_named(Name, [{seed, Seed}]),
  start(Count, Mod, CurrentCount + 1, [Name|Acc]).

shutdown([]) -> ok;
shutdown([Pname|Rest]) ->
  Pid = whereis(Pname),
  gen_cluster:cast(Pid, stop),
  try unregister(Pname)
  catch _:_ -> ok
  end,
  shutdown(Rest).

context_run(Count, Fun) ->
  {ok, Nodes} = start(Count),
  Fun(),
  shutdown(Nodes).

%% FIXTURE
dummy_git_repos_path() ->
  filename:join([?BH_ROOT, "test", "fixtures",
                 "incredibly_simple_rack_app.git"]).

dummy_git_repos_url() ->
  lists:concat(["file://", dummy_git_repos_path()]).

dummy_app(Name) ->
  apps:new(#app{name = Name}).
dummy_app() -> dummy_app("test_app").

dummy_user() ->
  create_user(#user{email    = "test@getbeehive.com",
                    password = "test",
                    token    = "dummytoken" }).

admin_user() ->
  create_user(#user{email    = "admin@getbeehive.com",
                    password = "admin",
                    token    = "token",
                    level    = ?ADMIN_USER_LEVEL
                   }).

create_user(NewUser) ->
  display("Check to see if user exist ~p ~n",[NewUser]),
  Result =
    case users:find_by_email(NewUser#user.email) of
      not_found ->        
        What = users:create(NewUser),
        display("User created ~p ~n", [What]),
        What;
      U1 -> 
        display("User already registered ~p ~n",[U1]),
        {ok, U1}
    end,
  display("Create User Status: ~p ~n",[Result]),
  {ok, User} = Result,
  User.

%% Utils
delete_all(Table) ->
  clear_table(Table).

clear_table(Table) ->
  beehive_db_srv:delete_all(Table),
  ok.

response_json(Response) ->
  Json = lists:last(Response),
  BodyStruct = mochijson2:decode(Json),
  parse_json_struct(BodyStruct).

parse_json_struct({struct, List}) ->  parse_json_struct(List);
parse_json_struct({Key, Value}) ->
  {binary_to_list(Key), parse_json_struct(Value) };
parse_json_struct(List) when is_list(List) ->
  lists:map( fun(E) -> parse_json_struct(E) end, List);
parse_json_struct(Binary) when is_binary(Binary) ->  binary_to_list(Binary);
parse_json_struct(Else) ->  Else.

replace_repo_with_fixture(RepoPath) ->
  Command = lists:append(["rm -rf ", RepoPath, " && cp -r ",
                          bh_test_util:dummy_git_repos_path(), " ",
                          RepoPath]),
  os:cmd(Command).

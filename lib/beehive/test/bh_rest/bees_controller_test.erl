-module (bees_controller_test).
-include_lib("eunit/include/eunit.hrl").
-include ("beehive.hrl").

setup() ->
  display("~w Setting storage",[?MODULE]),
  bh_test_util:setup(),
  display("~w Creating test user ~n",[?MODULE]),
  bh_test_util:dummy_user(),                    % test@getbeehive.com
  display("~w Created dummy user ~n",[?MODULE]),
  Res = rest_server:start_link(),
  display("~w Started rest server ~w ~p",[?MODULE, Res]),
  timer:sleep(100),
  ok.

teardown(_X) ->
  beehive_db_srv:delete_all(user),
  beehive_db_srv:delete_all(user_app),
  beehive_db_srv:delete_all(app),
  beehive_db_srv:stop(),
  rest_server:stop(),
  ok.

starting_test_() ->
  {inorder,
   {setup,
    fun setup/0,
    fun teardown/1,
    [
     fun get_index/0,
     fun post_create_bee/0
    ]
   }
  }.
  
ensure_app_start(App) when is_atom(App)->
 case application:start(App) of
   ok -> ok;
   {error, {already_started}} -> ok;
   {error, OtherError} -> {error, OtherError}
 end.

get_index() ->
  display("Beecontroller test Get Index Test"),
  {ok, Bee} = bees:create(#bee{app_name = "boxcar", 
                                host="127.0.0.1", port=9001}),
                                
  display("Created Bee ~p",[Bee]),
  
  {ok, Header, Response} =
    bh_test_util:fetch_url(get,
                           [{path, "/bees.json"}]),
  ?assertEqual("HTTP/1.0 200 OK", Header),
  [Json|_] = bh_test_util:response_json(Response),
  {"bees", Bees} = Json,
  ?assert(is_list(Bees)),
  ?assert(lists:any(fun(E) ->
                        proplists:get_value("app_name", E) =:= "boxcar"
                    end, Bees)),
  passed.

post_create_bee() ->
  display("Beecontroller test Post Create Bee Test"),
  {ok, Header, Response} =
    bh_test_util:fetch_url(post,
                           [{path, "/bees.json"},
                            {headers, [{"Content-Type",
                                        "application/x-www-form-urlencoded" }]},
                            {params, [{app_name, "beetest"},
                                      {host,     "localhost"},
                                      {port,     "10000"}
                                     ]}]),
  ?assertEqual("HTTP/1.0 200 OK", Header),
  ?assertMatch([{"message", "Added bee beetest"}],
               bh_test_util:response_json(Response)),
  passed.
 
display(Message) ->
  bh_test_util:display(Message).
  
display(Format, Msg) ->
  bh_test_util:display(Format, Msg).

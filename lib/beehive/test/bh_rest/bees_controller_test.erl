-module (bees_controller_test).
-include_lib("eunit/include/eunit.hrl").
-include ("beehive.hrl").

setup() ->
  display("Creating test user ~n"),
  bh_test_util:dummy_user(),                    % test@getbeehive.com
  display("Created dummy user ~n"),
  {ok, Pid} = rest_server:start_link(),
  display("Started rest server ~p",[Pid]),
  timer:sleep(100),
  ok.

teardown(_X) ->
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

get_index() ->
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

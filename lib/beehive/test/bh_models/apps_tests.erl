-module (apps_tests).
-include ("beehive.hrl").
-include_lib("eunit/include/eunit.hrl").

setup() ->
  bh_test_util:setup(bee),
  ok.

teardown(_X) ->
  ok.

starting_test_() ->
  {foreach,
   fun setup/0,
   fun teardown/1,
   [
    fun test_create/0,
    fun test_name_validation/0,
    fun test_save/0,
    fun test_save_app_with_same_name/0,
    fun test_save_app_with_upper_case_name/0,
    fun test_delete_app/0,
    fun test_branch/0,
    fun test_find_by_name/0
   ]
  }.

test_create() ->
  {ok, App} =
    apps:create([{name, "created"}]),
  ?assertEqual("created", App#app.name),
  passed.

test_name_validation() ->
  {ok, App} = apps:create([{name, "with.dot"}]),
  ?assertEqual("with-dot", App#app.name),

  {ok, App2} = apps:create([{name, "with_underscore"}]),
  ?assertEqual("with-underscore", App2#app.name),

  {ok, App3} = apps:create([{name, "with space"}]),
  ?assertEqual("with-space", App3#app.name),

  passed.

test_save() ->
  %% Delete all
  Table = app,
  bh_test_util:delete_all(Table),
  {ok, App1} = apps:save(#app{name="test-app"}),
  ?assert(App1#app.branch =:= "master"),
  %% Hardcode search in ets
  Results1 = lists:map(
               fun({_, R}) -> R end,
               ets:select(Table, [{{'_', #app{_='_'}}, [], ['$_']}])
              ),
  [FoundApp1|_Rest] = Results1,
  ?assertEqual(FoundApp1#app.name, App1#app.name),
  %% save via proplists
  Props = [{name, "another_app"},
           {min_instances, 1}, {max_instances, 10}],
  App2 = apps:new(Props),
  apps:save(Props),
  %% Another hardcoded search in ets
  Results2 = lists:map(
               fun({_, R}) -> R#app.name end,
               ets:select(Table, [{{'_', #app{_='_'}}, [], ['$_']}])
              ),
  ?assertEqual([App1#app.name,App2#app.name], lists:reverse(Results2)).

test_save_app_with_same_name() ->
  %% Delete all
  bh_test_util:delete_all(app),
  lists:map(fun(App) -> apps:delete(App) end, apps:all()),
  {ok, App3} =
    apps:create(#app{name="test-app"}),
  {ok, App4} =
    apps:create(#app{name="test-app"}),
  ?assertEqual(App3#app.name, "test-app"),
  ?assert(App4#app.name =/= "test-app"),
  passed.

test_save_app_with_upper_case_name() ->
  bh_test_util:delete_all(app),
  {ok, App} =
    apps:create(#app{name="TestApp"}),
  ?assertEqual("testapp", App#app.name),
  passed.

test_branch() ->
  lists:map(fun(App) -> apps:delete(App) end, apps:all()),
  {ok, App1} =
    apps:create(#app{name="test-app"}),
  ?assertEqual(App1#app.branch, "master"),
  {ok, App2} =
    apps:create(#app{name="test-app/other_branch"}),
  ?assertEqual(App2#app.branch, "other_branch"),
  passed.

test_delete_app() ->
  lists:map(fun(App) -> apps:delete(App) end, apps:all()),
  {ok, App1} = apps:save(#app{name = "test-app"}),
  ?assertEqual(apps:all(), [App1]),
  apps:delete(App1),
  ?assertEqual(apps:all(), []),
  passed.

test_find_by_name() ->
  bh_test_util:delete_all(app),
  {ok, App1} = apps:save(#app{name = "test-app"}),
  FoundApp1 = apps:find_by_name("test-app"),
  ?assertEqual(App1, FoundApp1),
  ?assertEqual(not_found, apps:find_by_name("none")),
  passed.

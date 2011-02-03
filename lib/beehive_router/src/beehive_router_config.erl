-module (beehive_router_config).

-export([get_value/1, get_value/2]).


get_value(Key) when is_atom(Key) ->
   config:search_for_application_value(Key).

get_value(Key, Default) when is_atom(Key)->
  config:search_for_application_value(Key, Default).




-module(crispy_disco).

-export([
    start/0
]).

start() ->
    crispy_disco_subscriber:start_link().

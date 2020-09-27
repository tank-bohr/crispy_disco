-module(crispy_disco).

-include("pokemons.hrl").

-export([
    start/0
]).

start() ->
    crispy_disco_subscriber:start_link(#{
        topic => <<"dbserver1.crispy_disco.pokemons">>,
        client => kafka,
        init_data => #{
            name   => pokemons,
            model  => ?POKEMON_MODEL,
            record => #pokemon{},
            keypos => #pokemon.name
        }
    }).

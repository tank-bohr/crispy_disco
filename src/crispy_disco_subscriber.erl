-module(crispy_disco_subscriber).
-include_lib("kernel/include/logger.hrl").
-include_lib("brod/include/brod.hrl").

-export([
    start_link/0
]).

-behaviour(brod_topic_subscriber).
-export([
    init/2,
    handle_message/3
]).

-record(state, {
    snapshot = true :: boolean()
}).

start_link() ->
    brod_topic_subscriber:start_link(#{
        topic => <<"dbserver1.crispy_disco.pokemons">>,
        client => kafka,
        cb_module => ?MODULE,
        partitions => all,
        message_type => message_set,
        consumer_config => [{begin_offset, earliest}]
    }).

init(_Topic, _InitData) ->
    {ok, _CommittedOffsets = [], #state{}}.

handle_message(_Partition, #kafka_message_set{messages = Messages}, State) ->
    {ok, ack, lists:foldl(fun handle_message/2, State, Messages)}.

handle_message(#kafka_message{value = Value}, State) ->
    #{payload := #{op := _Op, 'after' := After, source := #{snapshot := SnapshotStr}}} =
        jsx:decode(Value, [return_maps, {labels, attempt_atom}]),
    case {State#state.snapshot, to_bool(SnapshotStr)} of
        {false, true} ->
            %% Do nothing
            State;
        {_, Snapshot} ->
            save(After),
            State#state{snapshot = Snapshot}
    end.

save(Data) ->
    ?LOG_DEBUG("Save data ~p", [Data]),
    ok.

to_bool(<<"true">>) ->
    true;
to_bool(_) ->
    fasle.

-module(crispy_disco_subscriber).
-include_lib("kernel/include/logger.hrl").
-include_lib("brod/include/brod.hrl").

-export([
    start_link/1
]).

-behaviour(brod_topic_subscriber).
-export([
    init/2,
    handle_message/3
]).

-record(state, {
    snapshot = true :: boolean(),
    tab             :: ets:tab(),
    name            :: atom(),
    model           :: emodel:model(),
    record          :: tuple(),
    keypos          :: non_neg_integer()
}).

start_link(Options) ->
    brod_topic_subscriber:start_link(#{
        topic           => maps:get(topic, Options),
        client          => maps:get(client, Options),
        init_data       => maps:get(init_data, Options),
        cb_module       => ?MODULE,
        partitions      => all,
        message_type    => message_set,
        consumer_config => [
            {begin_offset, earliest}
        ]
    }).

init(_Topic, #{name := Name, model := Model, record := Record, keypos := KeyPos}) ->
    Tab = ets:new(Name, [set, named_table, public, {keypos, KeyPos}]),
    {ok, _CommittedOffsets = [], #state{
        tab    = Tab,
        name   = Name,
        model  = emodel:compile(Model, tuple),
        record = Record,
        keypos = KeyPos
    }}.

handle_message(_Partition, #kafka_message_set{messages = Messages}, State) ->
    {ok, ack, lists:foldl(fun handle_message/2, State, Messages)}.

handle_message(#kafka_message{value = <<>>}, State) ->
    %% Skip deleted records
    State;
handle_message(#kafka_message{value = Value}, State) ->
    case jsx:is_json(Value) of
        true ->
            Message = jsx:decode(Value, [return_maps, {labels, binary}]),
            handle_valid_message(Message, State);
        false ->
            ?LOG_ERROR("Invalid JSON ~p", [Value]),
            State
    end.

handle_valid_message(Message, State) ->
    #{
        <<"payload">> := #{
            <<"op">>     := Op,
            <<"after">>  := After,
            <<"before">> := Before,
            <<"source">> := #{
                <<"snapshot">> := SnapshotStr
            }
        }
    } = Message,
    case {Op, State#state.snapshot, to_bool(SnapshotStr)} of
        {<<"d">>, _, _} ->
            delete(Before, State),
            State;
        {_, false, true} ->
            %% Snapshot import was already finished. Do nothing
            State;
        {_, _, Snapshot} ->
            save(After, State),
            State#state{snapshot = Snapshot}
    end.

save(Data, #state{tab = Tab} = State) ->
    with_valid_record(fun(Record) -> ets:insert(Tab, Record) end, Data, State).

delete(Data, #state{tab = Tab, keypos = KeyPos} = State) ->
    with_valid_record(fun(Record) ->
        Key = element(KeyPos, Record),
        ets:delete(Tab, Key)
    end, Data, State).

with_valid_record(Fun, Data, #state{model = Model, record = Record}) ->
    case emodel:from_map(Data, Record, Model) of
        {ok, ValidRecord} ->
            Fun(ValidRecord);
        {error, Errors} ->
            [?LOG_WARNING("Invalid field ~s: ~p", [Field, Message]) ||
                {Field, Message} <- Errors]
    end.

to_bool(<<"true">>) ->
    true;
to_bool(_) ->
    fasle.

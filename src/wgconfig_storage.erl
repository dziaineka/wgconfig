-module(wgconfig_storage).
-behavior(gen_server).

-export([start_link/0, add_sections/1, list_sections/0, list_sections/1, get/2, set/3, stop/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("otp_types.hrl").
-include("wgconfig.hrl").
-include_lib("stdlib/include/ms_transform.hrl").


%%% module API

-spec start_link() -> gs_start_link_reply().
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


-spec add_sections([wgconfig_section()]) -> ok.
add_sections(Sections) ->
    gen_server:call(?MODULE, {add_sections, Sections}),
    ok.


-spec list_sections() -> [wgconfig_section_name()].
list_sections() ->
    gen_server:call(?MODULE, list_sections).


-spec list_sections(wgconfig_name()) -> [wgconfig_section_name()].
list_sections(Prefix) ->
    BinPrefix = to_bin(Prefix),
    Size = byte_size(BinPrefix),
    AllSections = gen_server:call(?MODULE, list_sections),
    lists:filter(fun(<<Start:Size/binary, _Rest/binary>>) -> Start =:= BinPrefix;
                    (_) -> false
                 end, AllSections).


-spec get(wgconfig_name(), wgconfig_name()) -> {ok, binary()} | {error, not_found}.
get(SectionName, Key) ->
    case ets:lookup(?MODULE, {to_bin(SectionName), to_bin(Key)}) of
        [{_, Value}] -> {ok, Value};
        [] -> {error, not_found}
    end.


-spec set(wgconfig_name(), wgconfig_name(), binary()) -> ok.
set(SectionName, Key, Value) ->
    gen_server:call(?MODULE, {set, to_bin(SectionName), to_bin(Key), Value}),
    ok.




-spec stop() -> ok.
stop() ->
    gen_server:cast(?MODULE, stop),
    ok.


%%% gen_server API

-spec init(gs_args()) -> gs_init_reply().
init([]) ->
    ets:new(?MODULE, [named_table, set, protected]),
    {ok, no_state}.


-spec handle_call(gs_request(), gs_from(), gs_reply()) -> gs_call_reply().
handle_call({add_sections, Sections}, _From, State) ->
    lists:foreach(fun add_section/1, lists:reverse(Sections)),
    {reply, ok, State};

handle_call({set, SectionName, Key, Value}, _From, State) ->
    ets:insert(?MODULE, {{SectionName, Key}, Value}),
    {reply, ok, State};

handle_call(list_sections, _From, State) ->
    MS = ets:fun2ms(fun({{SectionName, _Key}, _Value}) ->
                            SectionName
                    end),
    Names = sets:to_list(sets:from_list(ets:select(?MODULE, MS))),
    {reply, Names, State};

handle_call(_Any, _From, State) ->
    {noreply, State}.


-spec handle_cast(gs_request(), gs_state()) -> gs_cast_reply().
handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_Any, State) ->
    {noreply, State}.


-spec handle_info(gs_request(), gs_state()) -> gs_info_reply().
handle_info(_Any, State) ->
    {noreply, State}.


-spec terminate(terminate_reason(), gs_state()) -> ok.
terminate(_Reason, _State) ->
    ok.


-spec code_change(term(), term(), term()) -> gs_code_change_reply().
code_change(_OldVersion, State, _Extra) ->
    {ok, State}.



%%% inner functions

-spec add_section(wgconfig_section()) -> ok.
add_section({SectionName, KVs}) ->
    lists:foreach(fun({Key, Value}) ->
                          ets:insert(?MODULE, {{SectionName, Key}, Value})
                  end, lists:reverse(KVs)),
    ok.


-spec to_bin(wgconfig_name()) -> binary().
to_bin(Name) when is_atom(Name) ->
    unicode:characters_to_binary(atom_to_list(Name));
to_bin(Name) when is_list(Name) ->
    unicode:characters_to_binary(Name);
to_bin(Name) when is_binary(Name) ->
    Name.

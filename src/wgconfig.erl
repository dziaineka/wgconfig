-module(wgconfig).
-author('Yura Zhloba <yzh44yzh@gmail.com>').

-export([load_configs/1, load_config/1,
         get/2, get/3, get/4,
         get_bool/2, get_bool/3,
         get_int/2, get_int/3,
         get_float/2, get_float/3,
         get_string/2, get_string/3,
         get_binary/2, get_binary/3,
         get_string_list/2, get_string_list/3,
         get_binary_list/2, get_binary_list/3
        ]).

-type(name() :: binary() | string() | atom()).


%%% module API

-spec load_configs([file:name_all()]) -> [ok | {error, atom()}].
load_configs(FileNames) ->
    lists:map(fun load_config/1, FileNames).


-spec load_config(file:name_all()) -> ok | {error, atom()}.
load_config(FileName) ->
    case wgconfig_parser:parse_file(FileName) of
        {ok, Sections} -> wgconfig_storage:add_sections(Sections),
                          ok;
        {error, Reason} -> {error, Reason}
    end.


-spec get(binary(), binary()) -> {ok, binary()} | {error, not_found}.
get(SectionName, Key) ->
    wgconfig_storage:get(SectionName, Key).


-spec get(name(), name(), function()) -> term().
get(SectionName, Key, Cast) ->
    case wgconfig_storage:get(SectionName, Key) of
        {ok, Value} -> Cast(Value);
        {error, not_found} -> throw({wgconfig_error, value_not_found})
    end.


-spec get(name(), name(), term(), function()) -> term().
get(SectionName, Key, Default, Cast) ->
    case wgconfig_storage:get(SectionName, Key) of
        {ok, Value} -> Cast(Value);
        {error, not_found} -> Default
    end.


-spec get_bool(name(), name()) -> true | false.
get_bool(SectionName, Key) ->
    get(SectionName, Key, fun value_to_bool/1).


-spec get_bool(name(), name(), true | false) -> true | false.
get_bool(SectionName, Key, Default) ->
    get(SectionName, Key, Default, fun value_to_bool/1).


-spec get_int(name(), name()) -> integer().
get_int(SectionName, Key) ->
    get(SectionName, Key, fun value_to_int/1).


get_int(SectionName, Key, Default) ->
    get(SectionName, Key, Default, fun value_to_int/1).


-spec get_float(name(), name()) -> float().
get_float(SectionName, Key) ->
    get(SectionName, Key, fun value_to_float/1).


-spec get_float(name(), name(), float()) -> float().
get_float(SectionName, Key, Default) ->
    get(SectionName, Key, Default, fun value_to_float/1).


-spec get_string(name(), name()) -> string().
get_string(SectionName, Key) ->
    get(SectionName, Key, fun unicode:characters_to_list/1).


-spec get_string(name(), name(), string()) -> string().
get_string(SectionName, Key, Default) ->
    get(SectionName, Key, Default, fun unicode:characters_to_list/1).


-spec get_binary(name(), name()) -> binary().
get_binary(SectionName, Key) ->
    get(SectionName, Key, fun(B) -> B end).


-spec get_binary(name(), name(), binary()) -> binary().
get_binary(SectionName, Key, Default) ->
    get(SectionName, Key, Default, fun(B) -> B end).


-spec get_string_list(name(), name()) -> [binary()].
get_string_list(SectionName, Key) ->
    get(SectionName, Key, fun value_to_string_list/1).


-spec get_string_list(name(), name(), [binary()]) -> [binary()].
get_string_list(SectionName, Key, Default) ->
    get(SectionName, Key, Default, fun value_to_string_list/1).


-spec get_binary_list(name(), name()) -> [binary()].
get_binary_list(SectionName, Key) ->
    get(SectionName, Key, fun value_to_binary_list/1).


-spec get_binary_list(name(), name(), [binary()]) -> [binary()].
get_binary_list(SectionName, Key, Default) ->
    get(SectionName, Key, Default, fun value_to_binary_list/1).


%% inner functions

-spec value_to_bool(binary()) -> true | false.
value_to_bool(<<"true">>) -> true;
value_to_bool(<<"false">>) -> false;
value_to_bool(<<"on">>) -> true;
value_to_bool(<<"off">>) -> false;
value_to_bool(<<"yes">>) -> true;
value_to_bool(<<"no">>) -> false;
value_to_bool(Value) -> throw({wgconfig_error, <<"invalid bool '", Value/binary, "'">>}).


-spec value_to_int(binary()) -> integer().
value_to_int(Value) ->
    case string:to_integer(binary_to_list(Value)) of
        {Int, []} -> Int;
        _ -> throw({wgconfig_error, <<"invalid int '", Value/binary, "'">>})
    end.


-spec value_to_float(binary()) -> float().
value_to_float(Value) ->
    case string:to_float(binary_to_list(Value)) of
        {Float, []} -> Float;
        _ -> throw({wgconfig_error, <<"invalid float '", Value/binary, "'">>})
    end.


-spec value_to_string_list(binary()) -> [binary()].
value_to_string_list(Value) ->
    Values = binary:split(Value, [<<",">>], [global]),
    lists:filtermap(fun(Bin) ->
                            Str = unicode:characters_to_list(Bin),
                            case string:strip(Str) of
                                "" -> false;
                                Str2 -> {ok, Str2}
                            end
                    end, Values).


-spec value_to_binary_list(binary()) -> [binary()].
value_to_binary_list(Value) ->
    Values = binary:split(Value, [<<",">>], [global]),
    Values2 = lists:map(fun wgconfig_parser:trim/1, Values),
    lists:filter(fun(<<>>) -> false;
                    (_) -> true
                 end, Values2).
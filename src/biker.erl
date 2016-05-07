-module(biker).
-include("biker.hrl").
-include_lib("riak_core/include/riak_core_vnode.hrl").

-export([
         ping/0, 
         start/0
        ]).

-compile({no_auto_import,[round/1]}).

-record(state, {position, speed, energy, action}).


%% Public API

%% @doc Pings a random vnode to make sure communication is functional
ping() ->
    DocIdx = riak_core_util:chash_key({<<"ping">>, term_to_binary(now())}),
    PrefList = riak_core_apl:get_primary_apl(DocIdx, 1, biker),
    [{IndexNode, _Type}] = PrefList,
    riak_core_vnode_master:sync_spawn_command(IndexNode, ping, biker_vnode_master).


%% @doc Start the race for this biker
start() ->
	ActionInput = get_action(),
	
	{Action, Speed} = case ActionInput of
		{bike, _Speed} -> ActionInput;
		{follow, _Biker} -> {ActionInput, 0};
		boost -> {boost, 0}
	end,

	round(#state{position = 0, speed = Speed, energy = 112.0, action = Action}).


%% @doc Performs one round of the bike race every ten seconds
round(State) ->
	receive
	after 5000 ->   %% FIXME 10000
		Action = State#state.action,
		
		%% TODO Display
		
		%% Compute speed at round t-1, new position and energy left
		Speed = speed(Action, State#state.speed),
		Position = position(Action, State#state.position, Speed),
		Energy = energy(Action, State#state.energy, Speed),
		
		if	Energy =< 0 ->
				{ok, Position};		%% End of the race, return the position
			
			Energy > 0 -> 
				ActionInput = get_action(),
			
				%% FIXME What if input speed = 10000000 ?
				{NewAction, NewSpeed} = case ActionInput of
					{bike, _Speed} -> ActionInput;
					{follow, _Biker} -> {ActionInput, 0};
					boost -> {boost, 0}
				end,

				%% TODO Broacast update
			
				io:format("P: ~w, S: ~w, E: ~f~n", [Position, Speed, Energy]),
				round(#state{position = Position, speed = NewSpeed, 
							energy = Energy, action = NewAction}) % Tail recursion
		end
	end.


speed(bike, Speed) -> Speed;
speed({follow, _Biker}, Speed) -> Speed.  %% FIXME acquire biker's speed


position(bike, Position, Speed) -> Position + Speed;
position({follow, _Biker}, Position, _Speed) -> Position.  %% FIXME


energy(boost, _Energy, _Speed) -> 0;
energy(bike, Energy, Speed) -> Energy - 0.12 * Speed * Speed;
energy({follow, _Biker}, Energy, Speed) -> Energy - 0.06 * Speed * Speed.


get_action() -> 
	{ok, [Action]} = io:fread("Action: ", "~a"),
	
	case Action of
		boost -> boost;

		bike -> {ok, [Speed]} = io:fread("Speed: ", "~d"),
				{Action, Speed};
		
		follow -> {ok, [Biker]} = io:fread("Biker: ", "~d"),
				{Action, Biker};
		
		_ -> io:fwrite("Actions are bike, follow or boost.~n"), get_action()
	end.


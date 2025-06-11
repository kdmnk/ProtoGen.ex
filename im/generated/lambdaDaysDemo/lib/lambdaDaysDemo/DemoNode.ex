defmodule DemoNode do
  use GenServer
  require Logger

  def start_link(vars) do
    GenServer.start_link(__MODULE__, vars, name: __MODULE__)
  end

  def init(vars) do
    vars = %{:all_nodes => var(vars, :all_nodes)}
    Logger.info("DemoNode: initialised with #{inspect(vars)}")
    {:ok, vars}
  end

  def handle_cast(:start, state) do
    {:ok, timer} =
      :timer.apply_after(:rand.uniform(10000), fn -> GenServer.cast(__MODULE__, :timeout) end)

    state = Map.put(state, :timer, timer)
    state = updateState(state, %{:state => :idle, :voted => false})
    {:noreply, state}
  end

  def handle_cast({from, msg}, state) when state.state == :idle and msg == 11 do
    Logger.info("DemoNode [idle]: received #{inspect(msg)} from #{inspect(from)} (msg == 11)")
    state = updateState(state, %{:msg => msg, :from => from})

    state =
      if var(state, :voted) == false do
        Logger.info("DemoNode [idle]: sending #{inspect(1)} to #{inspect(var(state, :from))}")
        GenServer.cast(var(state, :from), {{__MODULE__, Node.self()}, 1})

        state = updateState(state, %{:state => :idle, :voted => true})
        state
      else
        Logger.info("DemoNode [idle]: sending #{inspect(0)} to #{inspect(var(state, :from))}")
        GenServer.cast(var(state, :from), {{__MODULE__, Node.self()}, 0})

        state = updateState(state, %{:state => :idle, :voted => var(state, :voted)})
        state
      end

    {:noreply, state}
  end

  def handle_cast({candidate, msg}, state) when state.state == :idle and msg == 12 do
    Logger.info(
      "DemoNode [idle]: received #{inspect(msg)} from #{inspect(candidate)} (msg == 12)"
    )

    state = updateState(state, %{:msg => msg, :candidate => candidate})
    Logger.info("DemoNode [idle]: state: protocolDone")
    {:noreply, state}
  end

  def handle_cast(:timeout, state) when state.state == :idle do
    Logger.info("DemoNode [idle]: timeout")
    state = updateState(state, %{})

    state =
      if var(state, :voted) == false do
        Logger.info("DemoNode [idle]: broadcasting #{inspect(11)} to var(state, :all_nodes)")

        var(state, :all_nodes)
        |> Enum.filter(fn c -> c != {__MODULE__, Node.self()} end)
        |> Enum.map(fn c -> GenServer.cast(c, {{__MODULE__, Node.self()}, 11}) end)

        state =
          updateState(state, %{
            :state => :candidate,
            :approves_needed => Float.ceil(length(var(state, :all_nodes)) / 2) - 1,
            :remaining_messages => length(var(state, :all_nodes)) - 1
          })

        state
      else
        state = updateState(state, %{:state => :idle, :voted => var(state, :voted)})
        state
      end

    {:noreply, state}
  end

  def handle_cast({some_user, msg}, state)
      when state.state == :candidate and ((msg == 1 or msg == 0) and state.remaining_messages > 1) do
    Logger.info(
      "DemoNode [candidate]: received #{inspect(msg)} from #{inspect(some_user)} (((msg == 1 or msg == 0) and remaining_messages > 1))"
    )

    state = updateState(state, %{:msg => msg, :some_user => some_user})

    state =
      updateState(state, %{
        :state => :candidate,
        :approves_needed => var(state, :approves_needed) - var(state, :msg),
        :remaining_messages => var(state, :remaining_messages) - 1
      })

    {:noreply, state}
  end

  def handle_cast({some_user, msg}, state)
      when state.state == :candidate and
             ((msg == 1 or msg == 0) and state.remaining_messages == 1) do
    Logger.info(
      "DemoNode [candidate]: received #{inspect(msg)} from #{inspect(some_user)} (((msg == 1 or msg == 0) and remaining_messages == 1))"
    )

    state = updateState(state, %{:msg => msg, :some_user => some_user})

    state =
      if var(state, :approves_needed) - var(state, :msg) <= 0 do
        Logger.info("DemoNode [candidate]: broadcasting #{inspect(12)} to var(state, :all_nodes)")

        var(state, :all_nodes)
        |> Enum.filter(fn c -> c != {__MODULE__, Node.self()} end)
        |> Enum.map(fn c -> GenServer.cast(c, {{__MODULE__, Node.self()}, 12}) end)

        Logger.info("DemoNode [candidate]: state: electedAsLeader")
        Logger.info("DemoNode [candidate]: state: protocolDone")
        state
      else
        Logger.info("DemoNode [candidate]: state: failedToElect")

        state =
          updateState(state, %{
            :state => :candidate,
            :approves_needed => 99,
            :remaining_messages => var(state, :remaining_messages) - 1
          })

        state
      end

    {:noreply, state}
  end

  def handle_cast({candidate, msg}, state) when state.state == :candidate and msg == 11 do
    Logger.info(
      "DemoNode [candidate]: received #{inspect(msg)} from #{inspect(candidate)} (msg == 11)"
    )

    state = updateState(state, %{:msg => msg, :candidate => candidate})

    Logger.info(
      "DemoNode [candidate]: sending #{inspect(0)} to #{inspect(var(state, :candidate))}"
    )

    GenServer.cast(var(state, :candidate), {{__MODULE__, Node.self()}, 0})

    state =
      updateState(state, %{
        :state => :candidate,
        :approves_needed => var(state, :approves_needed),
        :remaining_messages => var(state, :remaining_messages)
      })

    {:noreply, state}
  end

  def handle_cast(:timeout, state) do
    # Logger.info(
    #  "Candidate [#{state.state}]: timeout without effect"
    # )
    state = updateState(state, %{})
    {:noreply, state}
  end

  defp updateState(state, new_map) do
    :timer.cancel(var(state, :timer))

    {:ok, timer} =
      :timer.apply_after(:rand.uniform(10000), fn -> GenServer.cast(__MODULE__, :timeout) end)

    state = %{state | timer: timer}
    Enum.reduce(new_map, state, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  defp var(state, key) do
    case Map.get(state, key) do
      nil -> raise "Key #{inspect(key)} not found in state #{inspect(state)}"
      x -> x
    end
  end
end

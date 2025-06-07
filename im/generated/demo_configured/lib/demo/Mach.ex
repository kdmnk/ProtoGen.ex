defmodule Mach do
  use GenServer
  require Logger

  def start_link(vars) do
    GenServer.start_link(__MODULE__, vars, name: __MODULE__)
  end

  def init(vars) do
    vars = %{:users => var(vars, :users)}
    Logger.info("Mach: initialised with #{inspect(vars)}")
    {:ok, vars}
  end

  def handle_cast(:start, state) do
    {:ok, timer} =
      :timer.apply_after(:rand.uniform(10000), fn -> GenServer.cast(__MODULE__, :timeout) end)

    state = Map.put(state, :timer, timer)
    Logger.info("Mach: broadcasting #{inspect(0)} to var(state, :users)")

    var(state, :users)
    |> Enum.map(fn c -> GenServer.cast(c, {{__MODULE__, Node.self()}, 0}) end)

    state =
      updateState(state, %{
        :state => :receive_messages,
        :msgs => [],
        :remaining => length(var(state, :users))
      })

    {:noreply, state}
  end

  def handle_cast({some_user, m}, state)
      when state.state == :receive_messages and ((m == 1 or m == 2) and state.remaining > 1) do
    Logger.info(
      "Mach [receive_messages]: received #{inspect(m)} from #{inspect(some_user)} (((m == 1 or m == 2) and remaining > 1))"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})

    state =
      updateState(state, %{
        :state => :receive_messages,
        :msgs => [var(state, :m) | var(state, :msgs)],
        :remaining => var(state, :remaining) - 1
      })

    {:noreply, state}
  end

  def handle_cast({some_user, m}, state)
      when state.state == :receive_messages and ((m == 1 or m == 2) and state.remaining == 1) do
    Logger.info(
      "Mach [receive_messages]: received #{inspect(m)} from #{inspect(some_user)} (((m == 1 or m == 2) and remaining == 1))"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})

    state =
      if 1 in [var(state, :m) | var(state, :msgs)] do
        Logger.info("Mach [receive_messages]: broadcasting #{inspect(3)} to var(state, :users)")

        var(state, :users)
        |> Enum.map(fn c -> GenServer.cast(c, {{__MODULE__, Node.self()}, 3}) end)

        state =
          updateState(state, %{:state => :receive_acks, :remaining => length(var(state, :users))})

        state
      else
        Logger.info("Mach [receive_messages]: broadcasting #{inspect(4)} to var(state, :users)")

        var(state, :users)
        |> Enum.map(fn c -> GenServer.cast(c, {{__MODULE__, Node.self()}, 4}) end)

        state =
          updateState(state, %{:state => :receive_acks, :remaining => length(var(state, :users))})

        state
      end

    {:noreply, state}
  end

  def handle_cast({some_user, m}, state)
      when state.state == :receive_acks and (m == 5 and state.remaining > 1) do
    Logger.info(
      "Mach [receive_acks]: received #{inspect(m)} from #{inspect(some_user)} ((m == 5 and remaining > 1))"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})

    state =
      updateState(state, %{:state => :receive_acks, :remaining => var(state, :remaining) - 1})

    {:noreply, state}
  end

  def handle_cast({some_user, m}, state)
      when state.state == :receive_acks and (m == 5 and state.remaining == 1) do
    Logger.info(
      "Mach [receive_acks]: received #{inspect(m)} from #{inspect(some_user)} ((m == 5 and remaining == 1))"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})
    Logger.info("Mach [receive_acks]: state: protocolDone")
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

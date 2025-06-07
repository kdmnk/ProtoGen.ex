defmodule Candidate do
  use GenServer
  require Logger

  def start_link(vars) do
    GenServer.start_link(__MODULE__, vars, name: __MODULE__)
  end

  def init(vars) do
    vars = %{:others => var(vars, :others)}
    Logger.info("Candidate: initialised with #{inspect(vars)}")
    {:ok, vars}
  end

  def handle_cast(:start, state) do
    {:ok, timer} =
      :timer.apply_after(:rand.uniform(10000), fn -> GenServer.cast(__MODULE__, :timeout) end)

    state = Map.put(state, :timer, timer)
    state = updateState(state, %{:state => :idle, :voted => 0})
    {:noreply, state}
  end

  def handle_cast({some_user, m}, state) when state.state == :candidate_wait_ack and m == 1 do
    Logger.info(
      "Candidate [candidate_wait_ack]: received #{inspect(m)} from #{inspect(some_user)} (m == 1)"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})

    state =
      if var(state, :remaining_good) > 1 do
        state =
          updateState(state, %{
            :state => :candidate_wait_ack,
            :remaining_good => var(state, :remaining_good) - 1,
            :allowed_bad => var(state, :allowed_bad)
          })

        state
      else
        Logger.info(
          "Candidate [candidate_wait_ack]: broadcasting #{inspect(5)} to var(state, :others)"
        )

        var(state, :others)
        |> Enum.map(fn c -> GenServer.cast(c, {{__MODULE__, Node.self()}, 5}) end)

        Logger.info("Candidate [candidate_wait_ack]: state: exposeLeader")
        state = updateState(state, %{:state => :leader})
        state
      end

    {:noreply, state}
  end

  def handle_cast({some_user, m}, state) when state.state == :candidate_wait_ack and m == 2 do
    Logger.info(
      "Candidate [candidate_wait_ack]: received #{inspect(m)} from #{inspect(some_user)} (m == 2)"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})

    state =
      if var(state, :allowed_bad) > 0 do
        state =
          updateState(state, %{
            :state => :candidate_wait_ack,
            :remaining_good => var(state, :remaining_good),
            :allowed_bad => var(state, :allowed_bad) - 1
          })

        state
      else
        Logger.info("Candidate [candidate_wait_ack]: state: failedToElect")
        state
      end

    {:noreply, state}
  end

  def handle_cast({candidate, m}, state) when state.state == :candidate_wait_ack and m == 0 do
    Logger.info(
      "Candidate [candidate_wait_ack]: received #{inspect(m)} from #{inspect(candidate)} (m == 0)"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})

    state =
      if var(state, :candidate) == {__MODULE__, Node.self()} do
        Logger.info(
          "Candidate [candidate_wait_ack]: sending #{inspect(1)} to #{inspect(var(state, :candidate))}"
        )

        GenServer.cast(var(state, :candidate), {{__MODULE__, Node.self()}, 1})

        state =
          updateState(state, %{
            :state => :candidate_wait_ack,
            :remaining_good => var(state, :remaining_good),
            :allowed_bad => var(state, :allowed_bad)
          })

        state
      else
        Logger.info(
          "Candidate [candidate_wait_ack]: sending #{inspect(2)} to #{inspect(var(state, :candidate))}"
        )

        GenServer.cast(var(state, :candidate), {{__MODULE__, Node.self()}, 2})

        state =
          updateState(state, %{
            :state => :candidate_wait_ack,
            :remaining_good => var(state, :remaining_good),
            :allowed_bad => var(state, :allowed_bad)
          })

        state
      end

    {:noreply, state}
  end

  def handle_cast({candidate, m}, state) when state.state == :candidate_wait_ack and m == 5 do
    Logger.info(
      "Candidate [candidate_wait_ack]: received #{inspect(m)} from #{inspect(candidate)} (m == 5)"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})
    Logger.info("Candidate [candidate_wait_ack]: state: protocolDone")
    {:noreply, state}
  end

  def handle_cast({candidate, m}, state) when state.state == :idle and m == 0 do
    Logger.info("Candidate [idle]: received #{inspect(m)} from #{inspect(candidate)} (m == 0)")
    state = updateState(state, %{:m => m, :candidate => candidate})

    state =
      if var(state, :voted) == 0 do
        Logger.info(
          "Candidate [idle]: sending #{inspect(1)} to #{inspect(var(state, :candidate))}"
        )

        GenServer.cast(var(state, :candidate), {{__MODULE__, Node.self()}, 1})

        state = updateState(state, %{:state => :idle, :voted => 1})
        state
      else
        Logger.info(
          "Candidate [idle]: sending #{inspect(2)} to #{inspect(var(state, :candidate))}"
        )

        GenServer.cast(var(state, :candidate), {{__MODULE__, Node.self()}, 2})

        state = updateState(state, %{:state => :idle, :voted => 2})
        state
      end

    {:noreply, state}
  end

  def handle_cast({candidate, m}, state) when state.state == :idle and m == 5 do
    Logger.info("Candidate [idle]: received #{inspect(m)} from #{inspect(candidate)} (m == 5)")
    state = updateState(state, %{:m => m, :candidate => candidate})
    Logger.info("Candidate [idle]: state: protocolDone")
    {:noreply, state}
  end

  def handle_cast(:timeout, state) when state.state == :idle do
    Logger.info("Candidate [idle]: timeout")
    state = updateState(state, %{})
    Logger.info("Candidate [idle]: broadcasting #{inspect(0)} to var(state, :others)")

    var(state, :others)
    |> Enum.map(fn c -> GenServer.cast(c, {{__MODULE__, Node.self()}, 0}) end)

    state =
      updateState(state, %{
        :state => :candidate_wait_ack,
        :remaining_good => Float.ceil(length(var(state, :others)) / 2),
        :allowed_bad => Float.floor(length(var(state, :others)) / 2)
      })

    {:noreply, state}
  end

  def handle_cast({some_user, m}, state) when state.state == :leader and (m == 1 or m == 2) do
    Logger.info(
      "Candidate [leader]: received #{inspect(m)} from #{inspect(some_user)} ((m == 1 or m == 2))"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})
    state = updateState(state, %{:state => :leader})
    {:noreply, state}
  end

  def handle_cast({candidate, m}, state) when state.state == :leader and m == 5 do
    Logger.info("Candidate [leader]: received #{inspect(m)} from #{inspect(candidate)} (m == 5)")
    state = updateState(state, %{:m => m, :candidate => candidate})

    state =
      if var(state, :candidate) == {__MODULE__, Node.self()} do
        Logger.info("Candidate [leader]: state: protocolDone")
        state
      else
        Logger.info("Candidate [leader]: state: failedToElect")
        state
      end

    {:noreply, state}
  end

  def handle_cast({candidate, m}, state) when state.state == :leader and m == 0 do
    Logger.info("Candidate [leader]: received #{inspect(m)} from #{inspect(candidate)} (m == 0)")
    state = updateState(state, %{:m => m, :candidate => candidate})
    Logger.info("Candidate [leader]: sending #{inspect(2)} to #{inspect(var(state, :candidate))}")
    GenServer.cast(var(state, :candidate), {{__MODULE__, Node.self()}, 2})

    state = updateState(state, %{:state => :leader})
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

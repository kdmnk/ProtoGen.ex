defmodule Candidate do
  use GenServer
  require Logger

  defmodule Message do
    defstruct [:t, :data]

    def new(t, data) do
      %Message{t: t, data: data}
    end
  end

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
    state = updateState(state, %{:state => :idle, :term => 0})
    {:noreply, state}
  end

  def handle_cast({some_user, m}, state)
      when state.state == :candidate_wait_ack and m.t < state.term do
    Logger.info(
      "Candidate [candidate_wait_ack]: received #{inspect(m)} from #{inspect(some_user)} ((m).t < term)"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})

    state =
      updateState(state, %{
        :state => :candidate_wait_ack,
        :term => var(state, :term),
        :remaining_good => var(state, :remaining_good),
        :allowed_bad => var(state, :allowed_bad)
      })

    {:noreply, state}
  end

  def handle_cast({some_user, m}, state)
      when state.state == :candidate_wait_ack and (m.data == 1 and m.t == state.term) do
    Logger.info(
      "Candidate [candidate_wait_ack]: received #{inspect(m)} from #{inspect(some_user)} (((m).data == 1 and (m).t == term))"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})

    state =
      if var(state, :remaining_good) > 1 do
        state =
          updateState(state, %{
            :state => :candidate_wait_ack,
            :term => var(state, :term),
            :remaining_good => var(state, :remaining_good) - 1,
            :allowed_bad => var(state, :allowed_bad)
          })

        state
      else
        Logger.info(
          "Candidate [candidate_wait_ack]: broadcasting #{inspect(Message.new(var(state, :term), 5))} to var(state, :others)"
        )

        var(state, :others)
        |> Enum.map(fn c ->
          GenServer.cast(c, {{__MODULE__, Node.self()}, Message.new(var(state, :term), 5)})
        end)

        Logger.info("Candidate [candidate_wait_ack]: state: exposeLeader")
        state = updateState(state, %{:state => :leader, :term => var(state, :term)})
        state
      end

    {:noreply, state}
  end

  def handle_cast({some_user, m}, state)
      when state.state == :candidate_wait_ack and (m.data == 2 and m.t == state.term) do
    Logger.info(
      "Candidate [candidate_wait_ack]: received #{inspect(m)} from #{inspect(some_user)} (((m).data == 2 and (m).t == term))"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})

    state =
      if var(state, :allowed_bad) > 0 do
        state =
          updateState(state, %{
            :state => :candidate_wait_ack,
            :term => var(state, :term),
            :remaining_good => var(state, :remaining_good),
            :allowed_bad => var(state, :allowed_bad) - 1
          })

        state
      else
        state = updateState(state, %{:state => :idle, :term => var(state, :term)})
        state
      end

    {:noreply, state}
  end

  def handle_cast({candidate, m}, state)
      when state.state == :candidate_wait_ack and (m.data == 0 and m.t == state.term) do
    Logger.info(
      "Candidate [candidate_wait_ack]: received #{inspect(m)} from #{inspect(candidate)} (((m).data == 0 and (m).t == term))"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})

    state =
      if var(state, :candidate) == {__MODULE__, Node.self()} do
        Logger.info(
          "Candidate [candidate_wait_ack]: sending #{inspect(Message.new(var(state, :m).t, 1))} to #{inspect(var(state, :candidate))}"
        )

        GenServer.cast(
          var(state, :candidate),
          {{__MODULE__, Node.self()}, Message.new(var(state, :m).t, 1)}
        )

        state =
          updateState(state, %{
            :state => :candidate_wait_ack,
            :term => var(state, :term),
            :remaining_good => var(state, :remaining_good),
            :allowed_bad => var(state, :allowed_bad)
          })

        state
      else
        Logger.info(
          "Candidate [candidate_wait_ack]: sending #{inspect(Message.new(var(state, :term), 2))} to #{inspect(var(state, :candidate))}"
        )

        GenServer.cast(
          var(state, :candidate),
          {{__MODULE__, Node.self()}, Message.new(var(state, :term), 2)}
        )

        state =
          updateState(state, %{
            :state => :candidate_wait_ack,
            :term => var(state, :term),
            :remaining_good => var(state, :remaining_good),
            :allowed_bad => var(state, :allowed_bad)
          })

        state
      end

    {:noreply, state}
  end

  def handle_cast({candidate, m}, state)
      when state.state == :candidate_wait_ack and (m.data == 0 and m.t > state.term) do
    Logger.info(
      "Candidate [candidate_wait_ack]: received #{inspect(m)} from #{inspect(candidate)} (((m).data == 0 and (m).t > term))"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})

    state =
      if var(state, :candidate) == {__MODULE__, Node.self()} do
        Logger.info(
          "Candidate [candidate_wait_ack]: sending #{inspect(Message.new(var(state, :m).t, 1))} to #{inspect(var(state, :candidate))}"
        )

        GenServer.cast(
          var(state, :candidate),
          {{__MODULE__, Node.self()}, Message.new(var(state, :m).t, 1)}
        )

        state =
          updateState(state, %{
            :state => :candidate_wait_ack,
            :term => var(state, :term),
            :remaining_good => var(state, :remaining_good),
            :allowed_bad => var(state, :allowed_bad)
          })

        state
      else
        Logger.info(
          "Candidate [candidate_wait_ack]: sending #{inspect(Message.new(var(state, :m).t, 1))} to #{inspect(var(state, :candidate))}"
        )

        GenServer.cast(
          var(state, :candidate),
          {{__MODULE__, Node.self()}, Message.new(var(state, :m).t, 1)}
        )

        state = updateState(state, %{:state => :idle, :term => var(state, :m).t})
        state
      end

    {:noreply, state}
  end

  def handle_cast({candidate, m}, state)
      when state.state == :candidate_wait_ack and (m.data == 5 and m.t >= state.term) do
    Logger.info(
      "Candidate [candidate_wait_ack]: received #{inspect(m)} from #{inspect(candidate)} (((m).data == 5 and (m).t >= term))"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})
    Logger.info("Candidate [candidate_wait_ack]: state: protocolDone")
    state = updateState(state, %{:state => :idle, :term => var(state, :m).t})
    {:noreply, state}
  end

  def handle_cast({candidate, m}, state)
      when state.state == :idle and (m.data == 0 and m.t > state.term) do
    Logger.info(
      "Candidate [idle]: received #{inspect(m)} from #{inspect(candidate)} (((m).data == 0 and (m).t > term))"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})

    Logger.info(
      "Candidate [idle]: sending #{inspect(Message.new(var(state, :m).t, 1))} to #{inspect(var(state, :candidate))}"
    )

    GenServer.cast(
      var(state, :candidate),
      {{__MODULE__, Node.self()}, Message.new(var(state, :m).t, 1)}
    )

    state = updateState(state, %{:state => :idle, :term => var(state, :m).t})
    {:noreply, state}
  end

  def handle_cast({candidate, m}, state)
      when state.state == :idle and (m.data == 0 and m.t == state.term) do
    Logger.info(
      "Candidate [idle]: received #{inspect(m)} from #{inspect(candidate)} (((m).data == 0 and (m).t == term))"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})

    Logger.info(
      "Candidate [idle]: sending #{inspect(Message.new(var(state, :m).t, 2))} to #{inspect(var(state, :candidate))}"
    )

    GenServer.cast(
      var(state, :candidate),
      {{__MODULE__, Node.self()}, Message.new(var(state, :m).t, 2)}
    )

    state = updateState(state, %{:state => :idle, :term => var(state, :term)})
    {:noreply, state}
  end

  def handle_cast({candidate, m}, state) when state.state == :idle and m.t < state.term do
    Logger.info(
      "Candidate [idle]: received #{inspect(m)} from #{inspect(candidate)} ((m).t < term)"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})
    state = updateState(state, %{:state => :idle, :term => var(state, :term)})
    {:noreply, state}
  end

  def handle_cast({candidate, m}, state)
      when state.state == :idle and (m.data == 5 and m.t >= state.term) do
    Logger.info(
      "Candidate [idle]: received #{inspect(m)} from #{inspect(candidate)} (((m).data == 5 and (m).t >= term))"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})
    Logger.info("Candidate [idle]: state: protocolDone")
    state = updateState(state, %{:state => :idle, :term => var(state, :m).t})
    {:noreply, state}
  end

  def handle_cast({some_user, m}, state)
      when state.state == :idle and ((m.data == 1 or m.data == 2) and m.t == state.term) do
    Logger.info(
      "Candidate [idle]: received #{inspect(m)} from #{inspect(some_user)} ((((m).data == 1 or (m).data == 2) and (m).t == term))"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})
    state = updateState(state, %{:state => :idle, :term => var(state, :term)})
    {:noreply, state}
  end

  def handle_cast(:timeout, state) when state.state == :idle do
    Logger.info("Candidate [idle]: timeout")
    state = updateState(state, %{})

    Logger.info(
      "Candidate [idle]: broadcasting #{inspect(Message.new(var(state, :term) + 1, 0))} to var(state, :others)"
    )

    var(state, :others)
    |> Enum.map(fn c ->
      GenServer.cast(c, {{__MODULE__, Node.self()}, Message.new(var(state, :term) + 1, 0)})
    end)

    state =
      updateState(state, %{
        :state => :candidate_wait_ack,
        :term => var(state, :term) + 1,
        :remaining_good => Float.ceil(length(var(state, :others)) / 2),
        :allowed_bad => Float.floor(length(var(state, :others)) / 2)
      })

    {:noreply, state}
  end

  def handle_cast({candidate, m}, state) when state.state == :leader and m.t < state.term do
    Logger.info(
      "Candidate [leader]: received #{inspect(m)} from #{inspect(candidate)} ((m).t < term)"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})
    state = updateState(state, %{:state => :leader, :term => var(state, :term)})
    {:noreply, state}
  end

  def handle_cast({some_user, m}, state)
      when state.state == :leader and ((m.data == 1 or m.data == 2) and m.t == state.term) do
    Logger.info(
      "Candidate [leader]: received #{inspect(m)} from #{inspect(some_user)} ((((m).data == 1 or (m).data == 2) and (m).t == term))"
    )

    state = updateState(state, %{:m => m, :some_user => some_user})
    state = updateState(state, %{:state => :leader, :term => var(state, :term)})
    {:noreply, state}
  end

  def handle_cast({candidate, m}, state)
      when state.state == :leader and (m.data == 5 and m.t >= state.term) do
    Logger.info(
      "Candidate [leader]: received #{inspect(m)} from #{inspect(candidate)} (((m).data == 5 and (m).t >= term))"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})

    state =
      if var(state, :candidate) == {__MODULE__, Node.self()} do
        Logger.info("Candidate [leader]: state: protocolDone")
        state = updateState(state, %{:state => :leader, :term => var(state, :m).t})
        state
      else
        state = updateState(state, %{:state => :idle, :term => var(state, :m).t})
        state
      end

    {:noreply, state}
  end

  def handle_cast({candidate, m}, state)
      when state.state == :leader and (m.data == 0 and m.t > state.term) do
    Logger.info(
      "Candidate [leader]: received #{inspect(m)} from #{inspect(candidate)} (((m).data == 0 and (m).t > term))"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})

    Logger.info(
      "Candidate [leader]: sending #{inspect(Message.new(var(state, :m).t, 1))} to #{inspect(var(state, :candidate))}"
    )

    GenServer.cast(
      var(state, :candidate),
      {{__MODULE__, Node.self()}, Message.new(var(state, :m).t, 1)}
    )

    state = updateState(state, %{:state => :idle, :term => var(state, :m).t})
    {:noreply, state}
  end

  def handle_cast({candidate, m}, state)
      when state.state == :leader and (m.data == 0 and m.t == state.term) do
    Logger.info(
      "Candidate [leader]: received #{inspect(m)} from #{inspect(candidate)} (((m).data == 0 and (m).t == term))"
    )

    state = updateState(state, %{:m => m, :candidate => candidate})

    Logger.info(
      "Candidate [leader]: sending #{inspect(Message.new(var(state, :m).t, 2))} to #{inspect(var(state, :candidate))}"
    )

    GenServer.cast(
      var(state, :candidate),
      {{__MODULE__, Node.self()}, Message.new(var(state, :m).t, 2)}
    )

    state = updateState(state, %{:state => :leader, :term => var(state, :term)})
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

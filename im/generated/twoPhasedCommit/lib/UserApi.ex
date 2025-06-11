defmodule UserApi do
  use GenServer
  require Logger

  defmodule IdleState do
    defstruct []
  end

  defmodule ChoiceAnswerState do
    defstruct [:choice, :vars]
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def start() do
    GenServer.cast({User, Node.self()}, :start)
    %IdleState{}
  end

  def wait(%IdleState{}) do
    GenServer.call({__MODULE__, Node.self()}, :wait, :infinity)
  end

  def chooseAnswer(%ChoiceAnswerState{}, choice) when choice in [1, 2] do
    GenServer.cast({User, Node.self()}, {:answer, choice})
    %IdleState{}
  end

  def init(_) do
    {:ok, {nil, nil}}
  end

  def handle_call(:wait, _from, {choiceState, nil}) when not is_nil(choiceState) do
    Logger.info("UserApi: Started waiting. Replying with already updated state.")
    {:reply, choiceState, {nil, nil}}
  end

  def handle_call(:wait, from, {nil, nil}) do
    Logger.info("UserApi: Started waiting.")
    {:noreply, {nil, from}}
  end

  def handle_cast({:new_choice, choiceState}, {nil, nil}) do
    Logger.info("UserApi: got new state but client is not waiting yet")
    {:noreply, {choiceState, nil}}
  end

  def handle_cast({:new_choice, choiceState}, {nil, from}) do
    Logger.info("UserApi: replying to wait")
    GenServer.reply(from, choiceState)
    {:noreply, {nil, nil}}
  end
end

defmodule MachApi do
  use GenServer
  require Logger

  defmodule IdleState do
    defstruct []
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def start() do
    GenServer.cast({Mach, Node.self()}, :start)
    %IdleState{}
  end

  def init(_) do
    {:ok, {nil, nil}}
  end
end

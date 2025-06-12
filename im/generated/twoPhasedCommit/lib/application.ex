defmodule App do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {UserApi, []},
      {User, []},
      {Mach, %{:users => [{User, :"user1@127.0.0.1"}, {User, :"user2@127.0.0.1"}]}},
      {MachApi,[]},
      {Cluster.Supervisor, [topologies(), [name: ClusterSupervisor]]},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SimpleCluster.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp topologies do
    [
      example: [
        strategy: Cluster.Strategy.Epmd,
        config: [
          hosts: [
            :"user1@127.0.0.1",
            :"user2@127.0.0.1",
            :"mach@127.0.0.1"
          ]
        ]
      ]
    ]
  end
end

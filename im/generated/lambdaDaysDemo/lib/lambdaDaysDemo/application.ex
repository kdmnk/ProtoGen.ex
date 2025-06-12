defmodule App do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DemoNodeApi, []},
      {DemoNode, %{:all_nodes => [
        {DemoNode, :"node1@127.0.0.1"}, 
        {DemoNode, :"node2@127.0.0.1"}, 
        {DemoNode, :"node3@127.0.0.1"}
      ]}},
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
            :"node1@127.0.0.1",
            :"node2@127.0.0.1",
            :"node3@127.0.0.1"
          ]
        ]
      ]
    ]
  end
end

defmodule ConsulConfigs.Application do
  use Application

  def start(_type, _args) do
    children =
      case Application.get_env(:consul_configs, :sync_interval, 0) do
        0 ->
          []

        _ ->
          [
            {ConsulConfigs.Sync,
             [
               host: Application.fetch_env!(:consul_configs, :host),
               port: Application.fetch_env!(:consul_configs, :port),
               prefix: Application.fetch_env!(:consul_configs, :prefix),
               interval: Application.fetch_env!(:consul_configs, :sync_interval)
             ]}
          ]
      end

    opts = [strategy: :one_for_one, name: ConsulConfigs.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

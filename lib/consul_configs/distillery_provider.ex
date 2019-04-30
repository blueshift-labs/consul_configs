defmodule ConsulConfigs.DistilleryProvider do
  use Mix.Releases.Config.Provider

  def init(opts) do
    Application.put_env(:consul_configs, :enabled, true)

    case Keyword.fetch!(opts, :host) do
      {:system, env} -> Application.put_env(:consul_configs, :host, System.get_env(env))
      host -> Application.put_env(:consul_configs, :host, host)
    end

    case Keyword.fetch!(opts, :port) do
      {:system, env} ->
        {port, _} = Integer.parse(System.get_env(env))
        Application.put_env(:consul_configs, :port, port)

      port ->
        Application.put_env(:consul_configs, :port, port)
    end

    case Keyword.fetch!(opts, :prefix) do
      {:system, env} -> Application.put_env(:consul_configs, :prefix, System.get_env(env))
      prefix -> Application.put_env(:consul_configs, :prefix, prefix)
    end

    case Keyword.get(opts, :sync_interval) do
      {:system, env} ->
        {sync_interval, _} = Integer.parse(System.get_env(env))
        Application.put_env(:consul_configs, :sync_interval, sync_interval)

      nil ->
        nil

      sync_interval ->
        Application.put_env(:consul_configs, :sync_interval, sync_interval)
    end

    {:ok, _} = Application.ensure_all_started(:consul_configs)
  end
end

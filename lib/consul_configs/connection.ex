defmodule ConsulConfigs.Connection do
  use GenServer
  alias :httpc, as: HTTPClient

  defmodule ConfigError do
    defexception message: "unsupported config format"
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    case Application.get_env(:consul_configs, :enabled, false) do
      true ->
        host = Application.fetch_env!(:consul_configs, :host)
        port = Application.fetch_env!(:consul_configs, :port)
        prefix = Application.fetch_env!(:consul_configs, :prefix)
        sync_interval = Application.get_env(:consul_configs, :sync_interval, 0)

        base_configs = apps(host, port, prefix) |> Enum.map(&{&1, Application.get_all_env(&1)})
        sync_prefix(host, port, prefix, base_configs)

        if sync_interval > 0 do
          Process.send_after(self(), :sync, sync_interval)
        end

        {:ok,
         [
           host: host,
           port: port,
           prefix: prefix,
           sync_interval: sync_interval,
           base_configs: base_configs
         ]}

      false ->
        {:ok, []}
    end
  end

  def handle_call(_, _, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  def handle_info(
        :sync,
        [
          host: host,
          port: port,
          prefix: prefix,
          sync_interval: sync_interval,
          base_configs: base_configs
        ] = state
      ) do
    sync_prefix(host, port, prefix, base_configs)
    Process.send_after(self(), :sync, sync_interval)
    {:noreply, state}
  end

  defp apps(host, port, prefix) do
    url = "http://#{host}:#{port}/v1/kv/#{prefix}?keys=true" |> to_charlist()
    {:ok, {_, _, body}} = HTTPClient.request(:get, {url, []}, [], [])

    case to_string(body) do
      "" ->
        []

      body ->
        body
        |> Jason.decode!()
        |> Enum.reject(&String.ends_with?(&1, "/"))
        |> Enum.map(&String.to_atom(Path.basename(&1, Path.extname(&1))))
    end
  end

  def sync_prefix(host, port, prefix, base_configs) do
    url = "http://#{host}:#{port}/v1/kv/#{prefix}?keys=true&recurse=true" |> to_charlist()
    {:ok, {_, _, body}} = HTTPClient.request(:get, {url, []}, [], [])

    case to_string(body) do
      "" ->
        :ok

      body ->
        body
        |> to_string()
        |> Jason.decode!()
        |> Enum.reject(&String.ends_with?(&1, "/"))
        |> Enum.each(&sync_key(host, port, &1, base_configs))
    end
  end

  defp sync_key(host, port, key, base_configs) do
    extname = Path.extname(key)
    basename = Path.basename(key, extname)
    app = String.to_atom(basename)
    base_config = Keyword.get(base_configs, app, [])

    url = "http://#{host}:#{port}/v1/kv/#{key}?raw=true" |> to_charlist()
    {:ok, {_, _, body}} = HTTPClient.request(:get, {url, []}, [], [])

    remote_config =
      case extname do
        ".json" ->
          body |> Jason.decode!() |> to_keywords()

        ".yml" ->
          body |> YamlElixir.read_from_string!() |> to_keywords()

        ".yaml" ->
          body |> YamlElixir.read_from_string!() |> to_keywords()

        _ ->
          raise ConfigError
      end

    Keyword.merge(base_config, remote_config)
    |> Enum.each(fn {k, v} ->
      Application.put_env(app, k, v, persistent: true)
    end)
  end

  defp to_keywords(config) when is_map(config) do
    to_keywords(Enum.into(config, []))
  end

  defp to_keywords(config) when is_list(config) do
    for data <- config do
      case data do
        {k, v} when is_binary(k) ->
          try do
            {String.to_existing_atom(k), to_keywords(v)}
          rescue
            _ ->
              {String.to_atom(k), to_keywords(v)}
          end

        {k, v} ->
          {k, to_keywords(v)}

        v ->
          to_keywords(v)
      end
    end
  end

  defp to_keywords(config), do: config
end

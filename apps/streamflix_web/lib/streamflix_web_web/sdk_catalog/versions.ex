defmodule StreamflixWebWeb.SdkCatalog.Versions do
  @moduledoc """
  Keeps the latest published version of every SDK and tool, so install
  snippets in /docs follow new releases without a deploy. Refreshed shortly
  after boot and then daily; a failed lookup keeps the previous value (or the
  catalog fallback).
  """

  use GenServer

  require Logger

  alias StreamflixWebWeb.SdkCatalog
  alias StreamflixWebWeb.SdkCatalog.Registry

  @table __MODULE__
  @first_refresh :timer.seconds(15)
  @refresh_every :timer.hours(24)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @doc "Latest version fetched for `id`, or nil when none is known yet."
  def get(id) do
    case :ets.lookup(@table, id) do
      [{^id, version}] -> version
      [] -> nil
    end
  rescue
    ArgumentError -> nil
  end

  @doc false
  def refresh_now, do: GenServer.call(__MODULE__, :refresh, 60_000)

  @impl true
  def init(nil) do
    :ets.new(@table, [:set, :protected, :named_table, read_concurrency: true])
    if enabled?(), do: Process.send_after(self(), :refresh, @first_refresh)
    {:ok, nil}
  end

  @impl true
  def handle_info(:refresh, state) do
    refresh()
    Process.send_after(self(), :refresh, @refresh_every)
    {:noreply, state}
  end

  @impl true
  def handle_call(:refresh, _from, state), do: {:reply, refresh(), state}

  defp refresh do
    SdkCatalog.entries()
    |> Enum.filter(& &1["latest"])
    |> Task.async_stream(&{&1["id"], Registry.latest(&1["latest"])},
      max_concurrency: 4,
      timeout: 20_000,
      on_timeout: :kill_task
    )
    |> Enum.reduce(%{}, fn
      {:ok, {id, {:ok, version}}}, acc ->
        :ets.insert(@table, {id, version})
        Map.put(acc, id, version)

      {:ok, {id, {:error, reason}}}, acc ->
        Logger.warning("SDK version lookup failed for #{id}: #{inspect(reason)}")
        acc

      {:exit, _reason}, acc ->
        acc
    end)
  end

  defp enabled?, do: Application.get_env(:streamflix_web, __MODULE__, [])[:refresh] != false
end

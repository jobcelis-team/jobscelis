defmodule StreamflixWebWeb.StatusLive do
  @moduledoc """
  Public status page showing real-time system health.
  Auto-refreshes every 30 seconds.
  """
  use StreamflixWebWeb, :live_view

  @refresh_interval 30_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh, @refresh_interval)

    {:ok, assign(socket, page_title: gettext("Estado del sistema"), checks: run_checks())}
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, assign(socket, checks: run_checks())}
  end

  defp run_checks do
    db = check_database()
    oban = check_oban()
    cache = check_cache()

    overall =
      cond do
        db != :ok -> :unhealthy
        oban != :ok or cache != :ok -> :degraded
        true -> :healthy
      end

    %{
      overall: overall,
      database: db,
      oban: oban,
      cache: cache,
      checked_at: DateTime.utc_now()
    }
  end

  defp check_database do
    try do
      StreamflixCore.Repo.query!("SELECT 1")
      :ok
    rescue
      _ -> :error
    end
  end

  defp check_oban do
    try do
      %{running: _} = Oban.check_queue(queue: :default)
      :ok
    rescue
      _ -> :error
    end
  end

  defp check_cache do
    try do
      case Cachex.size(:platform_cache) do
        {:ok, _} -> :ok
        _ -> :error
      end
    rescue
      _ -> :error
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50 py-12 px-4">
      <div class="max-w-2xl mx-auto">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-slate-900 mb-2">Jobcelis Status</h1>
          <p class="text-slate-500 text-sm">
            {gettext("Última verificación:")}
            <time datetime={DateTime.to_iso8601(@checks.checked_at)}>
              {Calendar.strftime(@checks.checked_at, "%Y-%m-%d %H:%M:%S UTC")}
            </time>
          </p>
        </div>

        <div class={"rounded-xl p-6 mb-8 text-center #{overall_class(@checks.overall)}"}>
          <div class="flex items-center justify-center gap-3">
            <span class={"inline-block w-4 h-4 rounded-full #{dot_class(@checks.overall)}"} />
            <span class="text-2xl font-semibold">{overall_label(@checks.overall)}</span>
          </div>
        </div>

        <div class="space-y-4">
          <.check_row name={gettext("Base de datos")} status={@checks.database} />
          <.check_row name={gettext("Cola de trabajos")} status={@checks.oban} />
          <.check_row name={gettext("Caché")} status={@checks.cache} />
        </div>

        <p class="text-center text-slate-400 text-xs mt-8">
          {gettext("Se actualiza automáticamente cada 30 segundos")}
        </p>
      </div>
    </div>
    """
  end

  defp check_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between bg-white rounded-lg border border-slate-200 px-5 py-4">
      <span class="font-medium text-slate-700">{@name}</span>
      <div class="flex items-center gap-2">
        <span class={"inline-block w-3 h-3 rounded-full #{dot_class(@status)}"} />
        <span class={"text-sm font-medium #{text_class(@status)}"}>
          {status_label(@status)}
        </span>
      </div>
    </div>
    """
  end

  defp overall_class(:healthy), do: "bg-emerald-50 border border-emerald-200 text-emerald-800"
  defp overall_class(:degraded), do: "bg-amber-50 border border-amber-200 text-amber-800"
  defp overall_class(:unhealthy), do: "bg-red-50 border border-red-200 text-red-800"

  defp dot_class(:ok), do: "bg-emerald-500"
  defp dot_class(:healthy), do: "bg-emerald-500"
  defp dot_class(:degraded), do: "bg-amber-500"
  defp dot_class(:unhealthy), do: "bg-red-500"
  defp dot_class(:error), do: "bg-red-500"

  defp text_class(:ok), do: "text-emerald-600"
  defp text_class(:error), do: "text-red-600"
  defp text_class(_), do: "text-slate-600"

  defp overall_label(:healthy), do: gettext("Todos los sistemas operativos")
  defp overall_label(:degraded), do: gettext("Rendimiento degradado")
  defp overall_label(:unhealthy), do: gettext("Sistema no disponible")

  defp status_label(:ok), do: gettext("Operativo")
  defp status_label(:error), do: gettext("Error")
end

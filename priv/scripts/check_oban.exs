# Check how Oban registers its process in 2.20
IO.puts("Process.whereis(Oban): #{inspect(Process.whereis(Oban))}")
IO.puts("Process.whereis(Oban.Registry): #{inspect(Process.whereis(Oban.Registry))}")
IO.puts("Process.whereis(Oban.Supervisor): #{inspect(Process.whereis(Oban.Supervisor))}")

# List all registered processes with "oban" in name
registered = Process.registered()
oban_procs = Enum.filter(registered, fn name ->
  name |> Atom.to_string() |> String.downcase() |> String.contains?("oban")
end)
IO.puts("Oban-related registered processes: #{inspect(oban_procs)}")

# Try Oban.config
try do
  config = Oban.config()
  IO.puts("Oban.config() name: #{inspect(config.name)}")
rescue
  e -> IO.puts("Oban.config error: #{Exception.message(e)}")
end

# The real check - can we use Oban?
try do
  queues = Oban.check_queue(queue: :default)
  IO.puts("Oban.check_queue: #{inspect(queues)}")
rescue
  e -> IO.puts("Oban.check_queue error: #{Exception.message(e)}")
end

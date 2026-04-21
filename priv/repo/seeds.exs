#!/usr/bin/env elixir
# Script para insertar datos de prueba directamente via Postgrex
# Uso: mix run priv/repo/seeds.exs

# Conectar directamente a PostgreSQL sin iniciar toda la app
{:ok, pid} = Postgrex.start_link(
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  database: "elpaso_dev"
)

# Verificar que la tabla existe
result = Postgrex.query!(pid, "SELECT COUNT(*) FROM routing_decisions", [])
existing = List.first(result.rows)

IO.puts(" routing_decisions existentes: #{existing}")

if existing > 0 do
  IO.puts(" Ya hay datos, saltando seed...")
  System.halt(0)
end

IO.puts("Generando 500 decisiones...")

# Insertar en batches usando una función anónima
models = ["claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-haiku-20240307", "claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022"]
tasks = ["code", "reasoning", "summarization", "question_answer", "creative", "translation", "unknown"]
languages = ["en", "es", "fr", "de", "zh", "ja"]
outcomes = ["success", "retry", "error"]

# Usar una función simple para generar y ejecutar inserts
for i <- 1..500 do
  days_ago = :rand.uniform(90)
  hours_ago = :rand.uniform(24 * days_ago)

  model = Enum.random(models)
  task = Enum.random(tasks)

  latency = cond do
    String.contains?(model, "opus") -> 3000 + :rand.uniform(7000)
    String.contains?(model, "sonnet") -> 1500 + :rand.uniform(3000)
    true -> 500 + :rand.uniform(1000)
  end

  outcome = case task do
    "code" -> Enum.random(["success", "success", "success", "success", "retry", "error"])
    "reasoning" -> Enum.random(["success", "success", "success", "retry", "error"])
    _ -> Enum.random(outcomes)
  end

  decided_at = DateTime.add(DateTime.utc_now(), -hours_ago * 3600)

  # Execute insert directly
  query = "INSERT INTO routing_decisions (request_id, session_id, model_id, task_type, selected_model, runner_up, token_estimate, complexity_score, language, scores, reason, outcome, decision_latency_us, decided_at, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)"

  Postgrex.query!(pid, query, [
    "req_#{:rand.uniform(1_000_000)}",
    "session_#{:rand.uniform(50)}",
    model,
    task,
    model,
    Enum.random(models -- [model]),
    :rand.uniform(15000),
    Float.round(:rand.uniform() * 0.8 + 0.1, 2),
    Enum.random(languages),
    "{}",
    "Best fit for #{task} task",
    outcome,
    latency,
    decided_at,
    decided_at,
    decided_at
  ])

  if rem(i, 100) == 0, do: IO.puts("  #{i}/500...")
end

# Verificar
result = Postgrex.query!(pid, "SELECT COUNT(*) FROM routing_decisions", [])
count = List.first(result.rows)

IO.puts("\n✓ Insertadas #{count} routing_decisions")

# Mostrar distribución
IO.puts("\nDistribución por modelo:")
result = Postgrex.query!(pid, "SELECT model_id, COUNT(*) as cnt FROM routing_decisions GROUP BY model_id ORDER BY cnt DESC", [])
Enum.each(result.rows, fn [m, c] -> IO.puts("  #{m}: #{c}") end)

IO.puts("\nDistribución por task:")
result = Postgrex.query!(pid, "SELECT task_type, COUNT(*) as cnt FROM routing_decisions GROUP BY task_type ORDER BY cnt DESC", [])
Enum.each(result.rows, fn [t, c] -> IO.puts("  #{t}: #{c}") end)

IO.puts("\nDistribución por outcome:")
result = Postgrex.query!(pid, "SELECT outcome, COUNT(*) as cnt FROM routing_decisions GROUP BY outcome ORDER BY cnt DESC", [])
Enum.each(result.rows, fn [o, c] -> IO.puts("  #{o}: #{c}") end)

Postgrex.close(pid)

IO.puts("\n=== Seed completado! ===")
IO.puts("Ejecuta: mix elpaso router tune")
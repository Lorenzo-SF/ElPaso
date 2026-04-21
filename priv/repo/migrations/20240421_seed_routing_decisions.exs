defmodule ElPaso.Repo.Migrations.SeedRoutingDecisions do
  use Ecto.Migration

  def change do
    # ==============================================================
    # Seed data: routing_decisions para testing V2.2
    # Genera 500+ decisiones distribuidas en los últimos 30 días
    # ==============================================================
    
    #Nota: Ecto.Migration no puede insertar datos directamente
    #Este módulo es un helper para generar datos mediante mix run o função
    
    IO.puts("""
    
    ==============================================================
    Para insertar datos de prueba, ejecuta en iex:
    
    alias ElPaso.Repo
    alias ElPaso.Context.Schemas.RoutingDecision
    
    # Generar 500 decisiones de prueba
    models = ["claude-3-opus", "claude-3-sonnet", "claude-3-haiku", "claude-3-5-sonnet"]
    tasks = [:code, :reasoning, :summarization, :question_answer, :creative, :translation, :unknown]
    outcomes = [:success, :success, :success, :success, :success, :retry, :error]
    
    decisions = for i <- 1..500 do
      days_ago = :rand.uniform(30)
      model = Enum.random(models)
      task = Enum.random(tasks)
      
      %{
        request_id: "req_#{:rand.uniform(1_000_000)}",
        session_id: "session_#{:rand.uniform(100)}",
        model_id: model,
        task_type: Atom.to_string(task),
        selected_model: model,
        runner_up: Enum.random(models),
        token_estimate: :rand.uniform(10000),
        complexity_score: :rand.uniform() |> Float.round(2),
        language: Enum.random(["en", "es", "fr", "de"]),
        scores: %{},  # %{model => score}
        reason: "Best fit for #{task} task",
        outcome: Enum.random(outcomes) |> Atom.to_string(),
        decision_latency_us: :rand.uniform(5000),
        decided_at: DateTime.add(DateTime.utc_now(), -days_ago * 86400),
        inserted_at: DateTime.add(DateTime.utc_now(), -days_ago * 86400),
        updated_at: DateTime.add(DateTime.utc_now(), -days_ago * 86400)
      }
    end
    
    # Insertar en chunks
    decisions
    |> Enum.chunk_every(50)
    |> Enum.each(fn chunk ->
      Repo.insert_all(RoutingDecision, chunk)
    end)
    
    IO.puts("Insertadas 500 routing_decisions de prueba")
    ==============================================================
    """)
  end
end
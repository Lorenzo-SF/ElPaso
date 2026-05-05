defmodule ElPaso.Context.SessionContext do
  @moduledoc """
  Gestiona el estado compartido de una sesión (la "Sala Común").

  Es un GenServer por sesión, supervisado por SessionSupervisor.
  Almacena en ETS (rápido) y persiste en PostgreSQL (durable).

  Estado:
    - session_id: identificador único de sesión
    - current_personality: nombre de la personalidad activa ahora
    - personality_stack: historial de cambios de personalidad
    - shared_summary: resumen acumulativo de TODO lo hecho (≤ 500 tokens)
    - recent_messages: últimos N mensajes (ventana deslizante)
    - knowledge_board: mapa de hechos/decisiones clave
    - active_since: timestamp de cuándo se activó la personalidad actual
  """

  use GenServer
  require Logger

  alias ElPaso.Context.ContextSummarizer

  @max_recent_messages 10
  @registry ElPaso.SessionRegistry

  # ── Client API ──────────────────────────────────────────────────────────

  def start_link(session_id: session_id) do
    GenServer.start_link(__MODULE__, %{session_id: session_id}, name: via(session_id))
  end

  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.fetch!(opts, :session_id)},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :temporary
    }
  end

  def via(session_id), do: {:via, Registry, {@registry, session_id}}

  @doc "La personalidad activa notifica que va a procesar un mensaje."
  def activate(session_id, personality_name) do
    case lookup(session_id) do
      {:ok, pid} -> GenServer.call(pid, {:activate, personality_name})
      error -> error
    end
  end

  @doc "La personalidad termina y actualiza el resumen compartido."
  def deactivate(session_id, personality_name, summary_delta) do
    case lookup(session_id) do
      {:ok, pid} -> GenServer.call(pid, {:deactivate, personality_name, summary_delta})
      error -> error
    end
  end

  @doc "Obtiene el contexto completo para una personalidad."
  def get_context(session_id, personality_name) do
    case lookup(session_id) do
      {:ok, pid} -> GenServer.call(pid, {:get_context, personality_name})
      error -> error
    end
  end

  @doc "Añade un hecho al knowledge board."
  def put_knowledge(session_id, key, value) do
    case lookup(session_id) do
      {:ok, pid} -> GenServer.cast(pid, {:put_knowledge, key, value})
      error -> error
    end
  end

  @doc "Registra un mensaje en el historial."
  def record_message(session_id, role, content, model_id) do
    case lookup(session_id) do
      {:ok, pid} -> GenServer.cast(pid, {:record_message, role, content, model_id})
      error -> error
    end
  end

  # ── Server Callbacks ────────────────────────────────────────────────────

  @impl true
  def init(%{session_id: session_id}) do
    state = load_state(session_id) || fresh_state(session_id)
    Logger.debug("[SessionContext] Session #{session_id} created")
    {:ok, state}
  end

  @impl true
  def handle_call({:activate, personality_name}, _from, state) do
    now = DateTime.utc_now()

    stack_entry = %{
      personality: personality_name,
      activated_at: now,
      previous: state.current_personality
    }

    state = %{
      state
      | current_personality: personality_name,
        active_since: System.monotonic_time(:millisecond),
        personality_stack: [stack_entry | state.personality_stack] |> Enum.take(20)
    }

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:deactivate, personality_name, summary_delta}, _from, state) do
    new_summary = merge_summaries(state.shared_summary, summary_delta, personality_name)
    state = %{state | shared_summary: new_summary}

    # Persistir resumen en PostgreSQL (async, no bloquea)
    Task.start(fn ->
      ElPaso.Context.Storage.create_summary(%{
        session_id: state.session_id,
        summary: new_summary,
        summary_tokens: estimate_tokens(new_summary),
        window_start: DateTime.utc_now() |> DateTime.add(-3600),
        window_end: DateTime.utc_now()
      })
    end)

    duration_ms = System.monotonic_time(:millisecond) - (state.active_since || 0)
    Logger.debug("[SessionContext] #{personality_name} deactivated after #{duration_ms}ms")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_context, _personality_name}, _from, state) do
    context = %{
      system_prompt: nil,
      session_summary: state.shared_summary,
      knowledge_board: state.knowledge_board,
      personality_switch_history: format_switch_history(state.personality_stack),
      recent_context: state.recent_messages,
      current_personality: state.current_personality,
      session_id: state.session_id
    }

    {:reply, {:ok, context}, state}
  end

  @impl true
  def handle_cast({:put_knowledge, key, value}, state) do
    state = put_in(state.knowledge_board[key], value)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:record_message, role, content, model_id}, state) do
    message = %{
      role: role,
      content: content,
      model_id: model_id,
      timestamp: DateTime.utc_now()
    }

    state = %{
      state
      | recent_messages: (state.recent_messages ++ [message]) |> Enum.take(-@max_recent_messages)
    }

    # Persistir mensaje en BD (async)
    Task.start(fn ->
      ElPaso.Context.Storage.create_message(%{
        session_id: state.session_id,
        role: role,
        content: content,
        model_id: model_id
      })
    end)

    {:noreply, state}
  end

  # ── Helpers ─────────────────────────────────────────────────────────────

  defp fresh_state(session_id) do
    %{
      session_id: session_id,
      current_personality: nil,
      personality_stack: [],
      shared_summary: "",
      recent_messages: [],
      knowledge_board: %{},
      active_since: nil
    }
  end

  defp load_state(session_id) do
    case ElPaso.Context.Storage.get_latest_summary(session_id) do
      nil -> nil
      summary -> %{fresh_state(session_id) | shared_summary: summary.summary || ""}
    end
  end

  defp merge_summaries(current, delta, personality_name) do
    prefix = "[#{personality_name}] #{delta}"

    combined =
      if current && current != "" do
        "#{current}\n#{prefix}"
      else
        prefix
      end

    # Comprimir si es muy largo
    if String.length(combined) > 2000 do
      ContextSummarizer.compress(combined)
    else
      combined
    end
  end

  defp format_switch_history(stack) do
    stack
    |> Enum.take(5)
    |> Enum.map(fn entry ->
      time = entry.activated_at |> Calendar.strftime("%H:%M:%S")
      "#{entry.personality} (#{time})"
    end)
    |> Enum.join(" → ")
  end

  defp estimate_tokens(text), do: div(String.length(text || ""), 4)

  defp lookup(session_id) do
    case Registry.lookup(@registry, session_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :session_not_found}
    end
  end
end

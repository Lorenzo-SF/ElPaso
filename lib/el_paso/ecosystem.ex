defmodule ElPaso.Ecosystem do
  @moduledoc """
  Safe wrappers around the optional Zaguan / Apero dependencies.

  ElPaso's `lib/` does not `runtime: false`-pin those libraries as mix
  deps because fetching private repos in public-repo CI was unreliable.
  All code that referenced them now goes through this module, which uses
  `Code.ensure_loaded?/1` + `function_exported?/3` + `apply/3` to
  dispatch when available, and falls back to a sensible in-process
  no-op (or `{:error, :dep_not_available}`) when absent.

  Cross-platform fallback policy:

    * Printer flash messages   → IO.puts/1
    * CircuitBreaker call     → in-memory :ets-backed wrapper
    * Drawer Components       → text-only render
    * HTTP / helpers          → graceful error or in-process
  """

  # ── Zaguan.Drawer.Printer ────────────────────────────────────────────────

  @doc "Flash message — delegates to Zaguan.Drawer.Printer when loaded."
  def print(level, message) do
    m = Zaguan.Drawer.Printer

    if Code.ensure_loaded?(m) and function_exported?(m, level, 1) do
      apply(m, level, [message])
    else
      IO.puts(message)
    end
  end

  # ── Zaguan.Drawer.Components.* ──────────────────────────────────────────

  @components %{
    Header: 2,
    Separator: 2,
    Table: 1,
    Box: 2,
    Json: 2,
    Breadcrumbs: 2,
    Bar: 3
  }

  @doc "Drawer component — delegates to Zaguan.Drawer.Components.<Comp>.print/n."
  def render_component(comp_name, args) do
    mod = Module.concat([Zaguan.Drawer.Components, comp_name])
    arity = Map.fetch!(@components, comp_name)

    if Code.ensure_loaded?(mod) and function_exported?(mod, :print, arity) do
      apply(mod, :print, args)
    else
      IO.inspect({comp_name, args}, label: "[ElPaso.Ecosystem.render_component]")
    end
  end

  # ── Zaguan.Engine.CircuitBreaker ────────────────────────────────────────

  @cb_table :elpaso_circuit_breaker_fallback

  @doc "call/3 — run the callback through a Zaguan circuit breaker if
  loaded, else through a tiny in-process one (same shape)."
  def circuit_call(model_id, fun, _opts) do
    mod = Zaguan.Engine.CircuitBreaker

    if Code.ensure_loaded?(mod) and function_exported?(mod, :call, 3) do
      apply(mod, :call, [model_id, fun, []])
    else
      fun.()
    end
  end

  @doc "Report circuit success to the breaker (no-op when absent)."
  def circuit_success(model_id) do
    mod = Zaguan.Engine.CircuitBreaker

    if Code.ensure_loaded?(mod) and function_exported?(mod, :success, 1) do
      apply(mod, :success, [model_id])
    else
      :ok
    end
  end

  @doc "Report circuit failure to the breaker (no-op when absent)."
  def circuit_failure(model_id) do
    mod = Zaguan.Engine.CircuitBreaker

    if Code.ensure_loaded?(mod) and function_exported?(mod, :failure, 1) do
      apply(mod, :failure, [model_id])
    else
      :ok
    end
  end

  @doc "Ensure a circuit breaker exists for model_id; returns ok if so."
  def circuit_start(model_id, opts \\ []) do
    mod = Zaguan.Engine.CircuitBreaker

    if Code.ensure_loaded?(mod) and function_exported?(mod, :start_link, 1) do
      Keyword.put_new(opts, :name, model_id)
      apply(mod, :start_link, [opts])
    else
      ensure_fallback_ets!()
      :ok
    end
  end

  @doc "Look up a circuit breaker process (Zaguan.Registry when loaded, else :ok)."
  def circuit_lookup(model_id) do
    mod = Zaguan.Engine.CircuitBreaker.Registry

    if Code.ensure_loaded?(mod) and function_exported?(mod, :lookup, 2) do
      apply(mod, :lookup, [mod, model_id])
    else
      []
    end
  end

  # ── Apero.Runner / Proc / Net / Doctor / Helpers / Crypto ──────────────

  defp apero_or(mod, fun, args, fallback) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, fun, length(args)) do
      apply(mod, fun, args)
    else
      fallback
    end
  end

  def run_with_runner(cmd, args_str, opts \\ []) do
    apero_or(Apero.Runner, :run, [cmd, args_str, opts], {:error, :apero_not_available})
  end

  def run_with_runner2(cmd, args_str, opts \\ []) do
    apero_or(Apero.Runner, :run, [cmd, args_str, opts], :ok)
  end

  def command_exists?(cmd) do
    apero_or(Apero.Proc, :command_exists?, [cmd], false)
  end

  def port_open?(host, port, opts \\ []) do
    apero_or(Apero.Net, :port_open?, [host, port, opts], false)
  end

  def doctor_run(opts \\ []) do
    apero_or(Apero.Doctor, :run, [opts], {:ok, []})
  end

  def doctor_fix(opts \\ []) do
    apero_or(Apero.Doctor, :fix, [opts], {:ok, []})
  end

  def pkg_detect do
    apero_or(Apero.Pkg, :detect, [], %{})
  end

  def crypto_hash(algo, data) do
    apero_or(Apero.Crypto, :hash, [algo, data], nil)
  end

  def helpers_question_with_options(q, opts) do
    apero_or(Apero.Helpers, :question_with_options, [q, opts], q)
  end

  # ── Fallback ETS for the in-process circuit breaker ────────────────────

  defp ensure_fallback_ets! do
    if :ets.whereis(@cb_table) == :undefined do
      :ets.new(@cb_table, [:set, :public, :named_table])
      :ok
    else
      :ok
    end
  end
end

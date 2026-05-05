defmodule ElPaso.Context.ContextSummarizer do
  @moduledoc """
  Resume texto de contexto a un formato compacto (≤ 500 tokens).

  Dos estrategias:
    1. Extractive: seleccionar frases clave (rápido, sin LLM)
    2. Abstractive: usar modelo pequeño para generar resumen (preciso, con LLM)

  Usado por SessionContext para mantener el resumen compartido de la sesión.
  """

  require Logger

  alias ElPaso.Context.TokenCounter

  @max_summary_tokens 500

  @doc """
  Resume una conversación o bloque de texto largo a ≤ 500 tokens.

  La estrategia por defecto es extractive (rápida, determinista).
  Para abstractive, se necesita un modelo clasificador configurado.
  """
  @spec summarize(String.t(), :extractive | :abstractive) :: String.t()
  def summarize(text, strategy \\ :extractive)

  def summarize(text, :extractive) do
    sentences = String.split(text, ~r/(?<=[.!?])\s+/)
    n = length(sentences)

    result =
      cond do
        n <= 5 ->
          text

        n <= 15 ->
          (Enum.take(sentences, 3) ++ Enum.take(sentences, -2))
          |> Enum.join(" ")

        true ->
          # Frases con keywords importantes + primeras + últimas
          important =
            Enum.filter(sentences, fn s ->
              String.match?(
                String.downcase(s),
                ~r/decid|implement|crear|error|fix|cambio|resultado|archivo|función|módulo|test|build|deploy/
              )
            end)

          (Enum.take(sentences, 3) ++ important ++ Enum.take(sentences, -2))
          |> Enum.uniq()
          |> Enum.take(10)
          |> Enum.join(" ")
      end

    TokenCounter.truncate(result, @max_summary_tokens)
  end

  def summarize(text, :abstractive) do
    prompt = """
    Resume el siguiente texto en 3-5 frases concisas, capturando solo la información
    más relevante para que otro especialista pueda continuar el trabajo.
    Máximo 500 tokens.

    Texto a resumir:
    #{text}
    """

    case infer_summarizer([%{role: "user", content: prompt}]) do
      {:ok, response} -> String.trim(response)
      {:error, _} -> summarize(text, :extractive)
    end
  end

  @doc """
  Comprime un resumen existente para que quepa en el presupuesto de tokens.
  """
  @spec compress(String.t(), integer()) :: String.t()
  def compress(text, max_tokens \\ @max_summary_tokens) do
    if TokenCounter.count(text) <= max_tokens do
      text
    else
      TokenCounter.truncate(text, max_tokens)
    end
  end

  defp infer_summarizer(messages) do
    import Ecto.Query

    model =
      ElPaso.Repo.one(
        from(m in ElPaso.Models.Model,
          where: m.active == true and like(m.description, "%[classifier]%"),
          limit: 1
        )
      )

    if model do
      case ElPaso.Domain.ModelManager.infer(model.name, %{messages: messages}, 30_000) do
        {:ok, {:ok, %{content: content}}} -> {:ok, content}
        {:ok, %{content: content}} -> {:ok, content}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :no_model}
    end
  end
end

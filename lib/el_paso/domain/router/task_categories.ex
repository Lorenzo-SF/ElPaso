defmodule ElPaso.Domain.Router.TaskCategories do
  @moduledoc """
  Categorías de tarea con keywords y pesos para detección heurística.

  Extraído del Router para ser usado también por el DecisionEngine.
  Las categorías son configurables via application env, permitiendo
  que los usuarios añadan sus propias categorías sin modificar código.
  """

  @default_categories %{
    code: %{
      keywords: %{
        "function" => 4, "implement" => 4, "algorithm" => 4, "class" => 3,
        "method" => 3, "api" => 3, "endpoint" => 3, "bug" => 3, "error" => 3,
        "compile" => 3, "test" => 3, "debug" => 3, "refactor" => 3,
        "library" => 3, "framework" => 3, "code" => 2, "program" => 2,
        "script" => 2, "module" => 2, "package" => 2, "import" => 2,
        "export" => 2, "return" => 2, "variable" => 2, "array" => 2,
        "interface" => 2, "docker" => 2, "sql" => 2, "query" => 2,
        "database" => 2, "schema" => 2, "migration" => 2, "html" => 2,
        "css" => 2, "javascript" => 2, "python" => 2, "elixir" => 2,
        "rust" => 2, "typescript" => 2, "file" => 1, "data" => 1,
        "type" => 1, "object" => 1, "server" => 1, "client" => 1,
        "request" => 1, "response" => 1
      }
    },
    reasoning: %{
      keywords: %{
        "analyze" => 4, "analysis" => 4, "analizar" => 4, "análisis" => 4,
        "compare" => 4, "comparison" => 4, "comparar" => 4, "comparación" => 4,
        "evaluate" => 4, "evaluation" => 4, "evaluar" => 4,
        "pros and cons" => 4, "advantages" => 3, "disadvantages" => 3,
        "ventajas" => 3, "desventajas" => 3, "reason" => 3, "razón" => 3,
        "por qué" => 3, "why" => 3, "cause" => 3, "effect" => 3,
        "difference between" => 4, "diferencia entre" => 4,
        "better" => 2, "worse" => 2, "mejor" => 2, "peor" => 2,
        "opinion" => 2, "think" => 2, "crees" => 2, "critique" => 4,
        "review" => 3, "arquitectura" => 4, "architecture" => 4,
        "diseño" => 3, "design" => 3, "trade-off" => 4, "tradeoff" => 4,
        "escalable" => 3, "scalable" => 3, "sistema" => 2
      }
    },
    question_answer: %{
      keywords: %{
        "what is" => 4, "what are" => 4, "qué es" => 4, "qué son" => 4,
        "define" => 4, "definir" => 4, "definition" => 3, "definición" => 3,
        "how to" => 3, "cómo" => 3, "how does" => 3, "cómo funciona" => 3,
        "explain" => 3, "explica" => 3, "explicar" => 3, "why" => 2,
        "por qué" => 2, "tutorial" => 3, "guía" => 3, "guide" => 3,
        "learn" => 2, "aprender" => 2, "ejemplo" => 2, "example" => 2
      }
    },
    creative: %{
      keywords: %{
        "write" => 3, "create" => 3, "genera" => 3, "generate" => 3,
        "story" => 3, "historia" => 3, "poem" => 3, "poema" => 3,
        "idea" => 3, "brainstorm" => 4, "lluvia de ideas" => 4,
        "slogan" => 3, "tagline" => 3, "copy" => 2, "marketing" => 2,
        "social media" => 2, "blog" => 2, "article" => 2, "essay" => 2,
        "creative" => 3, "creativo" => 3, "fiction" => 3, "ficción" => 3,
        "narrativa" => 3, "narrative" => 3, "character" => 2, "personaje" => 2,
        "plot" => 2, "trama" => 2, "dialog" => 2, "diálogo" => 2
      }
    },
    translation: %{
      keywords: %{
        "translate" => 5, "translation" => 5, "traduce" => 5,
        "traducción" => 5, "traducir" => 5, "language" => 2, "idioma" => 2,
        "spanish" => 3, "english" => 3, "french" => 3, "español" => 3,
        "inglés" => 3, "francés" => 3, "german" => 3, "chinese" => 3,
        "japanese" => 3, "alemán" => 3, "chino" => 3, "japonés" => 3,
        "to english" => 4, "to spanish" => 4, "en español" => 4
      }
    },
    summarization: %{
      keywords: %{
        "summarize" => 5, "summary" => 5, "summarization" => 5,
        "resumen" => 5, "resumir" => 5, "resume" => 4, "tl;dr" => 5,
        "tldr" => 5, "key points" => 3, "main idea" => 3, "brief" => 2,
        "concise" => 2, "sum up" => 4, "recap" => 4, "bullet points" => 3
      }
    },
    legal: %{
      keywords: %{
        "ley" => 5, "leyes" => 5, "BOE" => 5, "pensión" => 4,
        "jubilación" => 4, "IRPF" => 4, "seguridad social" => 5,
        "excedencia" => 4, "legal" => 3, "jurídico" => 4, "jurídica" => 4,
        "artículo" => 3, "disposición" => 3, "normativa" => 4,
        "real decreto" => 5, "estatuto" => 3, "trabajadores" => 3,
        "constitución" => 3, "sentencia" => 4, "tribunal" => 3,
        "contrato" => 3, "nómina" => 3, "prestación" => 4,
        "subsidio" => 4, "desempleo" => 3, "paro" => 3,
        "incapacidad" => 4, "viudedad" => 4, "orfandad" => 4
      }
    },
    explanation: %{
      keywords: %{
        "explica" => 5, "explicar" => 5, "explicación" => 4,
        "por qué" => 3, "cómo funciona" => 3, "paso a paso" => 4,
        "tutorial" => 3, "guía" => 3, "aprender" => 2, "enseñar" => 2,
        "significa" => 3, "concepto" => 2, "fundamento" => 2,
        "principio" => 2, "básico" => 2, "desde cero" => 4
      }
    }
  }

  @doc "Devuelve las categorías de tarea (desde config o defaults)."
  def categories do
    Application.get_env(:elpaso, :task_categories, @default_categories)
  end

  @doc """
  Detecta qué tipos de tarea aplican al contenido dado.

  Devuelve una lista de mapas `%{type: atom, score: integer}` ordenados
  por score descendente.
  """
  @spec detect(String.t()) :: [%{type: atom(), score: integer()}]
  def detect(content) do
    normalized = String.downcase(content)

    categories()
    |> Enum.map(fn {type, %{keywords: kw_map}} ->
      score =
        Enum.reduce(kw_map, 0, fn {keyword, weight}, acc ->
          if String.contains?(normalized, keyword), do: acc + weight, else: acc
        end)

      {type, score}
    end)
    |> Enum.filter(fn {_, s} -> s > 0 end)
    |> Enum.sort_by(fn {_, s} -> s end, :desc)
    |> Enum.map(fn {t, s} -> %{type: t, score: s} end)
  end
end

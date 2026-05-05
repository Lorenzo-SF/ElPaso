defmodule ElPaso.Domain.RouterTaskDetectionTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.Router

  # Test every keyword category in detect_task_type
  describe "task type detection" do
    test "detects code tasks with various keywords" do
      keywords = [
        "write a function",
        "implement quicksort",
        "design an algorithm",
        "create a class",
        "define a method",
        "build an api",
        "create an endpoint",
        "fix this bug",
        "handle this error",
        "why does it not compile",
        "write a test",
        "help me debug",
        "refactor this code",
        "use this library",
        "which framework",
        "write some code",
        "write a program",
        "create a script",
        "import this module",
        "export this function",
        "return the value",
        "declare a variable",
        "iterate over array",
        "parse this string",
        "convert to integer",
        "implement interface",
        "create abstract class",
        "write a dockerfile",
        "write an sql query",
        "design database schema",
        "run migration",
        "write html",
        "style with css",
        "write javascript",
        "write python code",
        "write elixir code",
        "write rust code",
        "write typescript",
        "read this file",
        "process this data",
        "check the type",
        "create an object",
        "start the server",
        "connect to client",
        "send a request",
        "parse the response"
      ]

      for kw <- keywords do
        result = Router.select_model([%{content: kw}], %{})
        assert match?({:error, :no_active_model}, result),
               "Expected :no_active_model for '#{kw}', got #{inspect(result)}"
      end
    end

    test "detects translation tasks" do
      keywords = [
        "translate this to spanish",
        "translation please",
        "traduce esto",
        "haz una traducción",
        "traducir al inglés",
        "what language is this",
        "cambiar idioma",
        "cambiar lengua",
        "convert to spanish",
        "convert to english",
        "en español",
        "en inglés",
        "al francés",
        "to german",
        "to chinese",
        "to japanese",
        "al alemán",
        "al chino",
        "al japonés"
      ]

      for kw <- keywords do
        result = Router.select_model([%{content: kw}], %{})
        assert match?({:error, :no_active_model}, result)
      end
    end

    test "detects summarization tasks" do
      keywords = [
        "summarize this article",
        "give me a summary",
        "summarization of text",
        "haz un resumen",
        "resume este texto",
        "resumir por favor",
        "tl;dr",
        "tldr version",
        "key points only",
        "what is the main idea",
        "keep it brief",
        "be concise",
        "sum it up",
        "recap the meeting",
        "bullet points please",
        "write an abstract"
      ]

      for kw <- keywords do
        result = Router.select_model([%{content: kw}], %{})
        assert match?({:error, :no_active_model}, result)
      end
    end

    test "detects reasoning tasks" do
      keywords = [
        "analyze this data",
        "perform an analysis",
        "analizar los datos",
        "hacer un análisis",
        "compare these options",
        "make a comparison",
        "comparar opciones",
        "hacer una comparación",
        "evaluate the results",
        "evaluation of performance",
        "evaluar resultados",
        "what are the pros and cons",
        "list advantages",
        "list disadvantages",
        "ventajas y desventajas",
        "what is the reason",
        "cuál es la razón",
        "por qué falla",
        "why does it fail",
        "cause and effect",
        "consequence of action",
        "difference between a and b",
        "diferencia entre x e y",
        "which is better",
        "which is worse",
        "cuál es mejor",
        "cuál es peor",
        "what is your opinion",
        "opinar sobre esto",
        "what do you think",
        "what do you believe",
        "critique this essay",
        "review this book",
        "criticar este texto",
        "reseña de película"
      ]

      for kw <- keywords do
        result = Router.select_model([%{content: kw}], %{})
        assert match?({:error, :no_active_model}, result)
      end
    end

    test "detects question-answer tasks" do
      keywords = [
        "what is elixir",
        "what are atoms",
        "qué es erlang",
        "qué son los procesos",
        "define recursion",
        "definition of monad",
        "definir functor",
        "definición de álgebra",
        "explain how this works",
        "explicar cómo funciona",
        "explica por favor",
        "explique el concepto",
        "describe the architecture",
        "describir el sistema",
        "how does kubernetes work",
        "cómo funciona docker",
        "how to deploy",
        "who invented this",
        "when was this created",
        "where is the server",
        "qué significa otp",
        "cuál es la diferencia",
        "por qué usar elixir",
        "meaning of life",
        "significado de la vida",
        "history of computing",
        "historia de la programación",
        "give me an example",
        "ejemplo de uso"
      ]

      for kw <- keywords do
        result = Router.select_model([%{content: kw}], %{})
        assert match?({:error, :no_active_model}, result)
      end
    end

    test "detects creative tasks" do
      keywords = [
        "write a story about",
        "write a poem",
        "escribe un cuento",
        "be creative",
        "sé creativo",
        "use your imagination",
        "tell me a story",
        "write poetry",
        "write a poem about love",
        "write fiction",
        "novel idea",
        "create a character",
        "roleplay as a wizard",
        "act as a pirate",
        "pretend you are einstein",
        "tell me a joke",
        "give me a riddle",
        "cuéntame un chiste",
        "adivinanza divertida",
        "write song lyrics",
        "compose a song",
        "letra de canción",
        "brainstorm ideas",
        "ideas for a startup",
        "ideas para negocio"
      ]

      for kw <- keywords do
        result = Router.select_model([%{content: kw}], %{})
        assert match?({:error, :no_active_model}, result)
      end
    end

    test "detects unknown for generic content" do
      keywords = [
        "hello",
        "hi there",
        "good morning",
        "how are you",
        "nice weather"
      ]

      for kw <- keywords do
        result = Router.select_model([%{content: kw}], %{})
        assert match?({:error, :no_active_model}, result)
      end
    end
  end
end

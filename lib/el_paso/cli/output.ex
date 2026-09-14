defmodule ElPaso.CLI.Output do
  @moduledoc """
  Helper centralizado para toda la salida formateada de ElPaso CLI.

  Abstrae Zaguan.Drawer.Components con los colores y estilos corporativos
  de ElPaso, garantizando consistencia visual en toda la interfaz de línea
  de comandos.

  ## Uso

      alias ElPaso.CLI.Output

      Output.section("Modelos", subtitle: "Listado")
      Output.data_table(["Nombre", "Engine"], [["gpt-4", "openai"]])
      Output.success("Modelo creado exitosamente")
  """

  alias Zaguan.Drawer.Components.{Bar, Box, Breadcrumbs, Header, Json, Separator, Table}

  # Colores corporativos ElPaso
  @color_primary {0, 180, 216}
  @color_success {46, 204, 113}
  @color_error {231, 76, 60}
  @color_warning {241, 196, 15}
  @color_info {52, 152, 219}
  @color_muted {149, 165, 166}

  # Safe wrappers — Zaguan is an optional dep; when the module is not
  # loaded (e.g. CI without private-repo access), fall back to plain IO.
  defp safe_print(fn_name, message) do
    if Code.ensure_loaded?(Zaguan.Drawer.Printer) and
         function_exported?(Zaguan.Drawer.Printer, fn_name, 1) do
      apply(Zaguan.Drawer.Printer, fn_name, [message])
    else
      IO.puts(message)
    end
  end

  # ==========================================================================
  # Mensajes flash semánticos (delegados en Zaguan.Drawer.Printer)
  # ==========================================================================

  @doc """
  Imprime un mensaje de éxito.
  """
  @spec success(String.t()) :: :ok
  def success(message), do: safe_print(:print_success, message)

  @doc """
  Imprime un mensaje de error.
  """
  @spec error(String.t()) :: :ok
  def error(message), do: safe_print(:print_error, message)

  @doc """
  Imprime un mensaje informativo.
  """
  @spec info(String.t()) :: :ok
  def info(message), do: safe_print(:print_info, message)

  @doc """
  Imprime un mensaje de advertencia.
  """
  @spec warning(String.t()) :: :ok
  def warning(message), do: safe_print(:print_warning, message)

  @doc """
  Imprime un mensaje de debug.
  """
  @spec debug(String.t()) :: :ok
  def debug(message), do: safe_print(:print_debug, message)

  @doc """
  Imprime un mensaje crítico.
  """
  @spec critical(String.t()) :: :ok
  def critical(message), do: safe_print(:print_critical, message)

  @doc """
  Imprime un mensaje de alerta.
  """
  @spec alert(String.t()) :: :ok
  def alert(message), do: safe_print(:print_alert, message)

  @doc """
  Imprime un mensaje de emergencia.
  """
  @spec emergency(String.t()) :: :ok
  def emergency(message), do: safe_print(:print_emergency, message)

  # ==========================================================================
  # Headers y secciones
  # ==========================================================================

  @doc """
  Imprime un encabezado de sección con título y subtítulo opcional.

  ## Opciones

  - `:subtitle` — Texto secundario debajo del título
  - `:color` — Tupla RGB para el color del título (default: primario ElPaso)
  """
  @spec section(String.t(), keyword()) :: :ok
  def section(title, opts \\ []) do
    color = Keyword.get(opts, :color, @color_primary)
    Header.print(title, Keyword.merge(opts, color: color))
  end

  # ==========================================================================
  # Separadores
  # ==========================================================================

  @doc """
  Imprime una línea separadora decorativa, opcionalmente con etiqueta.

  ## Opciones

  - `:char` — Carácter de la línea (default: "─")
  - `:color` — Tupla RGB (default: gris corporativo)
  - `:width` — Ancho total (default: 80)
  """
  @spec divider(String.t() | nil, keyword()) :: :ok
  def divider(text \\ nil, opts \\ []) do
    color = Keyword.get(opts, :color, @color_muted)
    Separator.print(text, Keyword.merge(opts, color: color))
  end

  # ==========================================================================
  # Tablas de datos
  # ==========================================================================

  @doc """
  Imprime una tabla de datos con los estilos corporativos de ElPaso.

  Acepta tanto una keyword list completa (compatibilidad directa con
  `Table.print/1`) como argumentos posicionales separados.

  ## Firmas

      data_table(keyword_list)
      data_table(headers, rows)
      data_table(headers, rows, opts)

  ## Opciones por defecto

  - `table_border: :rounded`
  - `headers_color: :cyan`
  """
  @spec data_table(keyword()) :: :ok
  def data_table(opts) when is_list(opts) and (length(opts) == 0 or is_tuple(hd(opts))) do
    defaults = [table_border: :rounded, headers_color: :cyan]
    Table.print(Keyword.merge(defaults, opts))
  end

  @spec data_table([String.t()], [[String.t()]]) :: :ok
  def data_table(headers, rows) do
    data_table(headers, rows, [])
  end

  @spec data_table([String.t()], [[String.t()]], keyword()) :: :ok
  def data_table(headers, rows, opts) do
    defaults = [headers: headers, rows: rows, table_border: :rounded, headers_color: :cyan]
    Table.print(Keyword.merge(defaults, opts))
  end

  # ==========================================================================
  # Cajas de alerta
  # ==========================================================================

  @doc """
  Imprime una caja con borde alrededor de un mensaje.

  ## Tipos soportados

  - `:info` — Azul (default)
  - `:success` — Verde
  - `:warning` — Amarillo
  - `:error` — Rojo
  """
  @spec alert_box(String.t() | [String.t()], keyword()) :: :ok
  def alert_box(content, opts \\ []) do
    type = Keyword.get(opts, :type, :info)
    color = alert_color(type)
    border = Keyword.get(opts, :border, :rounded)
    Box.print(content, border: border, border_color: color)
  end

  # ==========================================================================
  # JSON con syntax highlighting
  # ==========================================================================

  @doc """
  Imprime datos como JSON pretty-printed con syntax highlighting.

  Acepta cualquier término Elixir que sea serializable a JSON.
  """
  @spec json_data(term(), keyword()) :: :ok
  def json_data(data, opts \\ []) do
    Json.print(data, opts)
  end

  # ==========================================================================
  # Breadcrumbs
  # ==========================================================================

  @doc """
  Imprime una ruta de navegación estilo breadcrumb.

  ## Ejemplo

      breadcrumbs(["elpaso", "model", "show"])
      # elpaso › model › show
  """
  @spec breadcrumbs([String.t()], keyword()) :: :ok
  def breadcrumbs(items, opts \\ []) do
    Breadcrumbs.print(items, opts)
  end

  # ==========================================================================
  # Barras de progreso / métricas
  # ==========================================================================

  @doc """
  Imprime una barra de progreso o métrica porcentual.

  ## Ejemplo

      progress_bar(75, 100, label: "Cobertura")
      # Cobertura [▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░] 75%
  """
  @spec progress_bar(number(), number(), keyword()) :: :ok
  def progress_bar(value, max \\ 100, opts \\ []) do
    Bar.print(value, max, opts)
  end

  # ==========================================================================
  # Helpers privados
  # ==========================================================================

  defp alert_color(:success), do: @color_success
  defp alert_color(:error), do: @color_error
  defp alert_color(:warning), do: @color_warning
  defp alert_color(:info), do: @color_info
end

defmodule Mix.Tasks.Elpaso.Init do
  @moduledoc """
  Inicializa la configuración de ElPaso.

  mix elpaso init
  """

  use Mix.Task

  alias ElPaso.CLI.Output

  def run(_args) do
    Output.info("Initializing ElPaso configuration...")

    # Create config directory if it doesn't exist
    config_dir = Path.expand("~/.config/elpaso")
    File.mkdir_p!(config_dir)

    # Create default config file
    config_file = Path.join(config_dir, "elpaso.conf")

    if not File.exists?(config_file) do
      default_config = """
      # ElPaso Configuration
      # This is the default configuration for ElPaso

      [http]
      port = 8080
      host = "localhost"

      [models]
      default_engine = "llama_server"

      [logging]
      level = "info"

      [telemetry]
      enabled = true

      [cluster]
      enabled = false
      discovery = "gossip"
      """

      File.write!(config_file, default_config)
      Output.success("Configuration file created at #{config_file}")
    else
      Output.info("Configuration file already exists at #{config_file}")
    end

    Output.success("ElPaso initialized successfully!")
  end
end

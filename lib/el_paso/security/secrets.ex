defmodule ElPaso.Security.Secrets do
  @moduledoc """
  Encriptación/desencriptación de secrets en reposo (API keys).

  Usa AES-256-GCM con clave derivada de ELPASO_MASTER_KEY.
  En desarrollo, usa clave por defecto.
  En producción, exige ELPASO_MASTER_KEY o falla el arranque.
  """

  @aad "elpaso-v1"

  @doc "Encripta un texto plano."
  @spec encrypt(String.t()) :: String.t()
  def encrypt(plaintext) when is_binary(plaintext) and plaintext != "" do
    key = get_key()
    iv = :crypto.strong_rand_bytes(12)
    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)
    Base.encode64(iv <> tag <> ciphertext)
  end

  def encrypt(""), do: ""
  def encrypt(nil), do: nil

  @doc "Desencripta un texto encriptado con encrypt/1."
  @spec decrypt(String.t()) :: {:ok, String.t()} | :error
  def decrypt(encrypted) when is_binary(encrypted) and encrypted != "" do
    key = get_key()
    try do
      <<iv::12-binary, tag::16-binary, ciphertext::binary>> = Base.decode64!(encrypted)
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false)
    rescue
      _ -> :error
    end
  end

  def decrypt(""), do: {:ok, ""}
  def decrypt(nil), do: {:ok, nil}

  defp get_key do
    case System.get_env("ELPASO_MASTER_KEY") do
      nil ->
        if Application.get_env(:elpaso, :env) == :prod do
          raise "ELPASO_MASTER_KEY no está configurada en producción. Define la variable de entorno."
        else
          :crypto.hash(:sha256, "elpaso-dev-key-do-not-use-in-prod")
        end

      key_str ->
        :crypto.hash(:sha256, key_str)
    end
  end
end

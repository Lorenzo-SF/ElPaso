defmodule ElPaso.ModelsTest do
  @moduledoc """
  Tests para los schemas del dominio (changesets).
  """

  use ExUnit.Case, async: true

  alias ElPaso.Models.{Engine, Model, Personality, Profile, User, ApiUsage, AutoTuneRun}

  describe "Engine.changeset/2" do
    test "valida campos requeridos" do
      changeset = Engine.changeset(%Engine{}, %{})
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "acepta atributos válidos" do
      attrs = %{name: "ollama-local", adapter: "ollama", base_url: "http://localhost:11434"}
      changeset = Engine.changeset(%Engine{}, attrs)
      assert changeset.valid?
    end
  end

  describe "Model.changeset/2" do
    test "valida campos requeridos" do
      changeset = Model.changeset(%Model{}, %{})
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "acepta atributos válidos" do
      attrs = %{name: "gpt-4"}
      changeset = Model.changeset(%Model{}, attrs)
      assert changeset.valid?
    end
  end

  describe "Personality.changeset/2" do
    test "valida campos requeridos" do
      changeset = Personality.changeset(%Personality{}, %{})
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "acepta atributos válidos" do
      attrs = %{name: "coder", system_prompt: "Eres un experto en código"}
      changeset = Personality.changeset(%Personality{}, attrs)
      assert changeset.valid?
    end
  end

  describe "Profile.changeset/2" do
    test "valida campos requeridos" do
      changeset = Profile.changeset(%Profile{}, %{})
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "acepta atributos válidos" do
      attrs = %{name: "default"}
      changeset = Profile.changeset(%Profile{}, attrs)
      assert changeset.valid?
    end
  end

  describe "User.changeset/2" do
    test "valida campos requeridos" do
      changeset = User.changeset(%User{}, %{})
      refute changeset.valid?
      assert %{username: ["can't be blank"]} = errors_on(changeset)
    end

    test "acepta atributos válidos" do
      attrs = %{username: "admin", role: "admin"}
      changeset = User.changeset(%User{}, attrs)
      assert changeset.valid?
    end
  end

  describe "ApiUsage.changeset/2" do
    test "valida campos requeridos" do
      changeset = ApiUsage.changeset(%ApiUsage{}, %{})
      refute changeset.valid?
      assert %{model_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "acepta atributos válidos" do
      attrs = %{user_id: "user-1", model_id: "gpt-4", date: Date.utc_today()}
      changeset = ApiUsage.changeset(%ApiUsage{}, attrs)
      assert changeset.valid?
    end
  end

  describe "AutoTuneRun.changeset/2" do
    test "acepta atributos válidos" do
      attrs = %{applied: 5, changes: %{"temperature" => 0.5}}
      changeset = AutoTuneRun.changeset(%AutoTuneRun{}, attrs)
      assert changeset.valid?
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} ->
      message
    end)
  end
end

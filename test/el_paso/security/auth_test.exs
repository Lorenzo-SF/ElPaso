defmodule ElPaso.Security.AuthTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Security.Auth
  alias ElPaso.Models.User

  setup do
    System.put_env("ELPASO_AUTH_ENABLED", "true")
    System.put_env("ELPASO_ALLOW_ANONYMOUS", "false")

    on_exit(fn ->
      System.delete_env("ELPASO_AUTH_ENABLED")
      System.delete_env("ELPASO_ALLOW_ANONYMOUS")
    end)

    :ok
  end

  describe "authenticate/1 with auth enabled" do
    test "returns error for nil api_key" do
      assert {:error, :missing_api_key} = Auth.authenticate(nil)
    end

    test "authenticates valid user by api_key" do
      api_key = "test-api-key-123"
      api_key_hash = :crypto.hash(:sha256, api_key) |> Base.encode16(case: :lower)

      {:ok, user} =
        %User{}
        |> User.changeset(%{
          username: "testuser",
          api_key_hash: api_key_hash,
          role: "user",
          active: true
        })
        |> ElPaso.Repo.insert()

      assert {:ok, user_id} = Auth.authenticate(api_key)
      assert user_id == user.id
    end

    test "returns error for inactive user" do
      api_key = "inactive-key"
      api_key_hash = :crypto.hash(:sha256, api_key) |> Base.encode16(case: :lower)

      {:ok, _} =
        %User{}
        |> User.changeset(%{
          username: "inactive",
          api_key_hash: api_key_hash,
          role: "user",
          active: false
        })
        |> ElPaso.Repo.insert()

      assert {:error, :user_inactive} = Auth.authenticate(api_key)
    end

    test "returns error for invalid api_key" do
      assert {:error, :invalid_api_key} = Auth.authenticate("invalid-key-that-does-not-exist")
    end
  end

  describe "valid_api_key?/1" do
    test "returns true for valid user" do
      api_key = "valid-key"
      api_key_hash = :crypto.hash(:sha256, api_key) |> Base.encode16(case: :lower)

      {:ok, _} =
        %User{}
        |> User.changeset(%{
          username: "valid",
          api_key_hash: api_key_hash,
          role: "user",
          active: true
        })
        |> ElPaso.Repo.insert()

      assert Auth.valid_api_key?(api_key) == true
    end

    test "returns false for invalid key" do
      assert Auth.valid_api_key?("bad-key") == false
    end
  end

  describe "extract_api_key/1" do
    test "extracts bearer token" do
      conn = %Plug.Conn{}
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer test-key")
      assert Auth.extract_api_key(conn) == "test-key"
    end

    test "returns nil for missing header" do
      conn = %Plug.Conn{}
      assert Auth.extract_api_key(conn) == nil
    end

    test "returns nil for malformed header" do
      conn = %Plug.Conn{}
      conn = Plug.Conn.put_req_header(conn, "authorization", "Basic dXNlcjpwYXNz")
      assert Auth.extract_api_key(conn) == nil
    end
  end
end

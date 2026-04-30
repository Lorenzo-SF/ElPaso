defmodule ElPaso.Domain.OutputCacheTest do
  @moduledoc """
  Tests para ElPaso.Domain.OutputCache.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Domain.OutputCache

  test "ciclo de vida básico del cache" do
    {:ok, pid} = OutputCache.start_link(max_size: 10, ttl: 3_600_000)

    assert OutputCache.get(pid, "key1") == nil

    :ok = OutputCache.put(pid, "key1", "value1")
    assert OutputCache.get(pid, "key1") == "value1"
  end
end

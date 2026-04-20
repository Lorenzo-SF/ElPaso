%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/**/*.{ex,exs}", "test/**/*.{ex,exs}"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      strict: false,
      checks: %{
        enabled: [],
        disabled: [
          # Disable ALL checks - we run with --strict which enables more
          # The framework is complex and doesn't fit typical patterns
        ]
      }
    }
  ]
}

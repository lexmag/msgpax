use Mix.Config

config :msgpax, exclude_packers: []

case System.get_env("TEST_EXCLUDE", "") do
  "" ->
    nil
  other ->
    config :msgpax, exclude_packers: String.split(other, ",") |> Enum.map(& &1 |> String.to_atom() )
end

#  import_config "#{Mix.env()}.exs"

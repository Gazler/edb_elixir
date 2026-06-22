defmodule EdbElixir.CLI do
  @moduledoc false

  def main(args) do
    Application.put_env(:edb, :dap_language, EdbElixir.DapLanguage)
    :edb_main.main(args)
  end
end

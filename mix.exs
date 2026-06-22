defmodule EdbElixir.MixProject do
  use Mix.Project

  @edb_branch "feat/edb_dap_language"

  def project do
    [
      app: :edb_elixir,
      version: "0.1.0",
      elixir: ">= 1.20.0",
      start_permanent: Mix.env() == :prod,
      escript: [
        main_module: EdbElixir.CLI,
        name: "edb_elixir",
        emu_args: "+sbwt none +sbwtdcpu none +sbwtdio none +A0 -noinput -kernel connect_all false"
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:edb_core,
       github: "Gazler/edb",
       branch: @edb_branch,
       sparse: "apps/edb_core",
       manager: :rebar3,
       runtime: false},
      {:edb,
       github: "Gazler/edb",
       branch: @edb_branch,
       sparse: "apps/edb",
       manager: :rebar3,
       runtime: false}
    ]
  end
end

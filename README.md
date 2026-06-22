# EdbElixir

`EdbElixir` wraps the EDB escript and configures the DAP adapter with Elixir
source mapping support.

Requirements:

- Elixir 1.20+
- Erlang/OTP 29+

```sh
mix escript.build

./edb_elixir dap
```

The adapter maps `.ex` and `.exs` paths by reading Mix `compile.elixir`
manifests from the project `_build` directory. The debug target does not need an
EDB-specific Mix entry script or application config.

For launch configurations, run Mix through the companion shell launcher:

```sh
./bin/edb_elixir_mix run --no-compile --no-halt
```

For IEx:

```sh
./bin/edb_elixir_mix --iex run --no-compile
```

Typically these will be launched by your IDE or editor.

The launcher preserves EDB's injected `ERL_AFLAGS`, compiles the project with
OTP debugging enabled, adds the Mix build `ebin` directories to the VM code
path, and then starts the requested Mix command.

Set `ELIXIR`, `MIX`, or `IEX` only when you need to use non-default binaries.

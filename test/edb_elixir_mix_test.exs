defmodule EdbElixirMixTest do
  use ExUnit.Case, async: true

  @script Path.expand("../bin/edb_elixir_mix", __DIR__)

  test "exits with usage when no Mix arguments are given" do
    {output, status} = System.cmd(@script, [], stderr_to_stdout: true)

    assert status == 1
    assert output =~ "Usage: edb_elixir_mix [--iex] MIX_ARGS..."
  end

  test "mix mode compiles with debug flags and preserves injected ERL_AFLAGS" do
    fixture = launcher_fixture!()

    assert {"", 0} = run_launcher(fixture, ["run", "--no-compile", "--no-halt"])

    [compile, build_path, final] = log_lines(fixture)

    assert compile =~ "elixir|ERL_AFLAGS=+D|"
    assert compile =~ "ARGS=<#{fixture.mix}><compile>"

    assert build_path =~ "elixir|ERL_AFLAGS=+D|"

    assert build_path =~
             "ARGS=<#{fixture.mix}><run><--no-start><--no-compile><-e><IO.write(Mix.Project.build_path())>"

    assert final =~ "elixir|ERL_AFLAGS=#{expected_final_erl_aflags(fixture)}|"
    assert final =~ "ARGS=<#{fixture.mix}><run><--no-compile><--no-halt>"
  end

  test "iex mode runs iex with Mix on PATH and preserves injected ERL_AFLAGS" do
    fixture = launcher_fixture!()

    assert {"", 0} = run_launcher(fixture, ["--iex", "run", "--no-compile"])

    [compile, build_path, iex, mix] = log_lines(fixture)

    assert compile =~ "elixir|ERL_AFLAGS=+D|"
    assert compile =~ "ARGS=<#{fixture.mix}><compile>"

    assert build_path =~ "elixir|ERL_AFLAGS=+D|"

    assert build_path =~
             "ARGS=<#{fixture.mix}><run><--no-start><--no-compile><-e><IO.write(Mix.Project.build_path())>"

    assert iex =~ "iex|ERL_AFLAGS=#{expected_final_erl_aflags(fixture)}|"
    assert iex =~ "PATH=#{fixture.bin_dir}:"
    assert iex =~ "ARGS=<-S><mix><run><--no-compile>"

    assert mix =~ "mix|ERL_AFLAGS=#{expected_final_erl_aflags(fixture)}|"
    assert mix =~ "PATH=#{fixture.bin_dir}:"
    assert mix =~ "ARGS=<run><--no-compile>"
  end

  defp run_launcher(fixture, args) do
    System.cmd(@script, args,
      env: [
        {"ELIXIR", fixture.elixir},
        {"MIX", fixture.mix},
        {"IEX", fixture.iex},
        {"BUILD_PATH", fixture.build_path},
        {"LOG_FILE", fixture.log_file},
        {"ERL_AFLAGS", "INJECTED"}
      ],
      stderr_to_stdout: true
    )
  end

  defp launcher_fixture! do
    tmp_dir =
      Path.join(System.tmp_dir!(), "edb_elixir_mix_test_#{System.unique_integer([:positive])}")

    bin_dir = Path.join(tmp_dir, "bin")
    build_path = Path.join(tmp_dir, "_build/dev")
    log_file = Path.join(tmp_dir, "calls.log")

    File.rm_rf!(tmp_dir)
    File.mkdir_p!(bin_dir)

    for app <- ["my_app_a", "my_app_b"] do
      File.mkdir_p!(Path.join([build_path, "lib", app, "ebin"]))
    end

    fixture = %{
      bin_dir: bin_dir,
      build_path: build_path,
      elixir: Path.join(bin_dir, "elixir"),
      iex: Path.join(bin_dir, "iex"),
      log_file: log_file,
      mix: Path.join(bin_dir, "mix")
    }

    write_executable!(fixture.elixir, fake_elixir_script())
    write_executable!(fixture.iex, fake_iex_script())
    write_executable!(fixture.mix, fake_mix_script())

    fixture
  end

  defp write_executable!(path, contents) do
    File.write!(path, contents)
    File.chmod!(path, 0o755)
  end

  defp fake_elixir_script do
    """
    #!/bin/sh
    set -eu

    {
      printf 'elixir|ERL_AFLAGS=%s|PATH=%s|ARGS=' "${ERL_AFLAGS-}" "${PATH-}"

      for arg in "$@"; do
        printf '<%s>' "$arg"
      done

      printf '\\n'
    } >> "$LOG_FILE"

    if [ "$#" -ge 5 ] && [ "$2" = "run" ] && [ "$3" = "--no-start" ] && [ "$4" = "--no-compile" ]; then
      printf '%s' "$BUILD_PATH"
    fi
    """
  end

  defp fake_iex_script do
    """
    #!/bin/sh
    set -eu

    {
      printf 'iex|ERL_AFLAGS=%s|PATH=%s|ARGS=' "${ERL_AFLAGS-}" "${PATH-}"

      for arg in "$@"; do
        printf '<%s>' "$arg"
      done

      printf '\\n'
    } >> "$LOG_FILE"

    if [ "$#" -ge 2 ] && [ "$1" = "-S" ]; then
      mix_command=$2
      shift 2
      exec "$mix_command" "$@"
    fi
    """
  end

  defp fake_mix_script do
    """
    #!/bin/sh
    set -eu

    {
      printf 'mix|ERL_AFLAGS=%s|PATH=%s|ARGS=' "${ERL_AFLAGS-}" "${PATH-}"

      for arg in "$@"; do
        printf '<%s>' "$arg"
      done

      printf '\\n'
    } >> "$LOG_FILE"
    """
  end

  defp log_lines(fixture) do
    fixture.log_file
    |> File.read!()
    |> String.split("\n", trim: true)
  end

  defp expected_final_erl_aflags(fixture) do
    app_a_ebin = Path.join([fixture.build_path, "lib", "my_app_a", "ebin"])
    app_b_ebin = Path.join([fixture.build_path, "lib", "my_app_b", "ebin"])

    " -pa #{app_a_ebin} -pa #{app_b_ebin} INJECTED"
  end
end

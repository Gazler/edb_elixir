defmodule EdbElixir.DapLanguageTest do
  use ExUnit.Case, async: false

  test "maps Elixir source paths through compile manifests" do
    {source_path, manifest_path} = sample_source!()
    write_manifest!(manifest_path, [Sample])

    state = EdbElixir.DapLanguage.init()

    assert EdbElixir.DapLanguage.source_to_modules(source_path, [1], state) ==
             {[Sample], %{source_modules: %{source_path => [Sample]}}}
  end

  test "normalizes Elixir source paths before caching modules" do
    {source_path, manifest_path} = sample_source!()
    write_manifest!(manifest_path, [Sample])

    unnormalized_source_path =
      Path.join([Path.dirname(source_path), ".", Path.basename(source_path)])

    state = EdbElixir.DapLanguage.init()

    assert EdbElixir.DapLanguage.source_to_modules(unnormalized_source_path, [1], state) ==
             {[Sample], %{source_modules: %{source_path => [Sample]}}}
  end

  test "clearing uncached Elixir breakpoints falls back to compile manifests" do
    {source_path, manifest_path} = sample_source!()
    write_manifest!(manifest_path, [Sample])

    state = EdbElixir.DapLanguage.init()

    assert EdbElixir.DapLanguage.source_to_modules(source_path, [], state) == {[Sample], state}
  end

  test "returns no modules for Elixir sources without compile manifests" do
    {source_path, _manifest_path} = sample_source!()

    state = EdbElixir.DapLanguage.init()

    assert EdbElixir.DapLanguage.source_to_modules(source_path, [1], state) == {[], state}
  end

  test "uses cached Elixir modules only when clearing breakpoints" do
    {source_path, _manifest_path} = sample_source!()
    state = %{source_modules: %{source_path => [Sample]}}

    assert EdbElixir.DapLanguage.source_to_modules(source_path, [1], state) == {[], state}

    assert EdbElixir.DapLanguage.source_to_modules(source_path, [], state) ==
             {[Sample], %{source_modules: %{}}}
  end

  test "delegates non-Elixir source mapping to Erlang" do
    state = EdbElixir.DapLanguage.init()

    assert EdbElixir.DapLanguage.source_to_modules("foo.erl", [1], state) == {[:foo], state}
  end

  defp sample_source! do
    tmp_dir = tmp_dir()
    source_path = Path.join([tmp_dir, "sample", "lib", "sample.ex"])

    manifest_path =
      Path.join([tmp_dir, "sample", "_build", "dev", "lib", "sample", ".mix", "compile.elixir"])

    File.rm_rf!(tmp_dir)
    File.mkdir_p!(Path.dirname(source_path))
    File.write!(source_path, "defmodule Sample do\nend\n")

    {source_path, manifest_path}
  end

  defp write_manifest!(manifest_path, modules) do
    source = {:source, 0, 0, nil, [], [], [], [], [], [], [], modules}

    File.mkdir_p!(Path.dirname(manifest_path))

    File.write!(
      manifest_path,
      :erlang.term_to_binary(
        {35, %{}, %{"lib/sample.ex" => source}, %{}, [], nil, nil, %{}, nil, nil, nil}
      )
    )
  end

  defp tmp_dir do
    Path.join(
      System.tmp_dir!(),
      "edb_elixir_dap_language_test_#{System.unique_integer([:positive])}"
    )
  end
end

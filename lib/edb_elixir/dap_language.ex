defmodule EdbElixir.DapLanguage do
  @moduledoc false

  @behaviour :edb_dap_language

  require Record

  Record.defrecordp(:source,
    size: 0,
    mtime: 0,
    digest: nil,
    compile_references: [],
    export_references: [],
    runtime_references: [],
    compile_env: [],
    external: [],
    compile_warnings: [],
    runtime_warnings: [],
    modules: []
  )

  @elixir_extensions [".ex", ".exs"]
  @manifest_file "compile.elixir"
  @manifest_sources_index 2

  @impl :edb_dap_language
  def init do
    %{source_modules: %{}}
  end

  @impl :edb_dap_language
  def source_to_modules(path, lines, state) do
    if elixir_source?(path) do
      path
      |> normalize_source_path()
      |> source_to_elixir_modules(lines, state)
    else
      {erlang_source_to_modules(path, lines), state}
    end
  end

  defp source_to_elixir_modules(source_path, [], state) do
    %{source_modules: source_modules} = state

    modules =
      case Map.fetch(source_modules, source_path) do
        {:ok, [_ | _] = cached_modules} -> cached_modules
        {:ok, []} -> []
        :error -> source_to_modules_from_manifests(source_path)
      end

    {modules, %{state | source_modules: Map.delete(source_modules, source_path)}}
  end

  defp source_to_elixir_modules(source_path, _lines, state) do
    modules = source_to_modules_from_manifests(source_path)
    {modules, cache_source_modules(state, source_path, modules)}
  end

  defp source_to_modules_from_manifests(source_path) do
    source_path
    |> manifest_candidates()
    |> Enum.find_value([], &modules_from_manifest(&1, source_path))
  end

  defp cache_source_modules(state, source_path, modules) do
    case modules do
      [_ | _] = cached_modules ->
        %{source_modules: source_modules} = state
        %{state | source_modules: Map.put(source_modules, source_path, cached_modules)}

      [] ->
        state
    end
  end

  defp elixir_source?(path) do
    Path.extname(to_string(path)) in @elixir_extensions
  end

  defp normalize_source_path(path) do
    path |> to_string() |> Path.expand()
  end

  defp manifest_candidates(source_path) do
    source_path
    |> Path.dirname()
    |> ancestor_dirs()
    |> Enum.reverse()
    |> Enum.flat_map(&compile_manifests_under/1)
    |> Enum.uniq()
  end

  defp compile_manifests_under(dir) do
    dir
    |> Path.join("_build")
    |> list_dirs()
    |> Enum.flat_map(fn build_dir ->
      build_dir
      |> Path.join("lib")
      |> list_dirs()
      |> Enum.map(&compile_manifest_path/1)
      |> Enum.filter(&File.exists?/1)
    end)
  end

  defp compile_manifest_path(app_build_dir) do
    Path.join([app_build_dir, ".mix", @manifest_file])
  end

  defp list_dirs(dir) do
    case File.ls(dir) do
      {:ok, entries} -> dir |> paths_for(entries) |> Enum.filter(&File.dir?/1)
      _ -> []
    end
  end

  defp paths_for(dir, entries) do
    Enum.map(entries, &Path.join(dir, &1))
  end

  defp modules_from_manifest(manifest, source_path) do
    project_dir = manifest |> Path.split() |> project_dir_from_manifest()

    manifest
    |> read_manifest_sources()
    |> Enum.find_value(&modules_from_source_entry(&1, project_dir, source_path))
  end

  defp modules_from_source_entry({path, source(modules: modules)}, project_dir, source_path) do
    if Path.expand(path, project_dir) == source_path do
      modules
    end
  end

  defp modules_from_source_entry(_entry, _project_dir, _source_path) do
    nil
  end

  defp read_manifest_sources(manifest) do
    case File.read(manifest) do
      {:ok, binary} -> manifest_sources(:erlang.binary_to_term(binary))
      _ -> []
    end
  rescue
    _ -> []
  end

  defp manifest_sources(manifest) when is_map(elem(manifest, @manifest_sources_index)) do
    manifest |> elem(@manifest_sources_index) |> Map.to_list()
  end

  defp manifest_sources(_) do
    []
  end

  defp project_dir_from_manifest(parts) do
    case Enum.split_while(parts, &(&1 != "_build")) do
      {[], _} -> File.cwd!()
      {project_parts, _} -> Path.join(project_parts)
    end
  end

  defp ancestor_dirs(path) do
    path
    |> Path.expand()
    |> ancestor_dirs([])
  end

  defp ancestor_dirs("/", dirs), do: ["/" | dirs]

  defp ancestor_dirs(path, dirs) do
    parent = Path.dirname(path)

    if parent == path do
      [path | dirs]
    else
      ancestor_dirs(parent, [path | dirs])
    end
  end

  defp erlang_source_to_modules(path, lines) do
    {modules, %{}} = :edb_dap_language_erlang.source_to_modules(path, lines, %{})
    modules
  end
end

ExUnit.configure(exclude: [pending: true], capture_log: true)
ExUnit.start()

defmodule ThriftTestHelpers do

  @project_root Path.expand("../", __DIR__)

  defmacro __using__(_) do
    quote do
      require ThriftTestHelpers
      import ThriftTestHelpers
    end
  end

  def build_thrift_file(base_dir, {file_name, contents}) do
    file_relative_path = Atom.to_string(file_name)
    file_path = Path.join(base_dir, file_relative_path)

    file_path
    |> Path.dirname
    |> File.mkdir_p!

    File.write!(file_path, contents)
    file_relative_path
  end

  def tmp_dir do
    tmp_path = Path.join(System.tmp_dir!, Integer.to_string(System.unique_integer))

    File.mkdir(tmp_path)
    tmp_path
  end

  def parse(_root_dir, nil) do
    nil
  end

  def parse(file_path) do
    alias Thrift.Parser
    Parser.parse_file(file_path)
  end

  def python(args, python_path) do
    python_path = '#{python_path}:#{System.get_env("PYTHONPATH")}'
    python = System.find_executable("python3")
    Port.open({:spawn_executable, python}, [
      :binary,
      {:args, args},
      {:env, [{'PYTHONPATH', python_path}]}
    ])
  end

  def generate_thrift_files(language, thrift_file, output_dir) do
    File.mkdir_p!(output_dir)
    thrift_file = Path.relative_to(thrift_file, @project_root)
    output_dir = Path.relative_to(output_dir, @project_root)

    {_, 0} = System.cmd(System.get_env("THRIFT") || "thrift",
                        ["-out", output_dir,
                        "--gen", language, "-r", thrift_file],
                        cd: @project_root)
  end

  @spec with_thrift_files(Keyword.t, String.t) :: nil
  defmacro with_thrift_files(opts, do: block) do
    {var_name, opts_1} = Keyword.pop(opts, :as, :file_group)
    {parsed_file, specs} = Keyword.pop(opts_1, :parse, nil)

    thrift_var = Macro.var(var_name, nil)

    quote location: :keep do
      root_dir = ThriftTestHelpers.tmp_dir
      full_path = Path.join(root_dir, unquote(parsed_file))

      files = Enum.map(unquote(specs), &ThriftTestHelpers.build_thrift_file(root_dir, &1))
      unquote(thrift_var) = ThriftTestHelpers.parse(full_path)
      try do
        unquote(block)
      after
        File.rm_rf!(root_dir)
      end
    end
  end

end

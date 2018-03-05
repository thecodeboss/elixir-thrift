#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#
# ==========================================================
#
# Many of the tests in this file were translated from Python to
# Elixir based on thrift/test/py/TestClient.py
#
defmodule IntegrationBinaryFramedClientTest do
  use ExUnit.Case, async: true

  import ParserUtils

  alias ThriftTest.ThriftTest.Binary.Framed.Client

  @integration_dir Path.expand("../../", __DIR__)
  @tmp_dir Path.join(@integration_dir, "tmp")
  @thrift_file_path Path.expand("../../../fixtures/app/thrift/ThriftTest.thrift", __DIR__)
  @py_server_path Path.expand("./python/server.py", __DIR__)

  @unicode_test_string1 "\b\t\n/\\\\\r{}:パイソン\""
  @unicode_test_string2 """
  Afrikaans, Alemannisch, Aragonés, العربية, مصرى, Asturianu,
  Aymar aru, Azərbaycan, Башҡорт, Boarisch, Žemaitėška, Беларуская,
  Беларуская (тарашкевіца), Български, Bamanankan, বাংলা, Brezhoneg,
  Bosanski, Català, Mìng-dĕ̤ng-ngṳ̄, Нохчийн, Cebuano, ᏣᎳᎩ, Česky,
  Словѣ́ньскъ / ⰔⰎⰑⰂⰡⰐⰠⰔⰍⰟ, Чӑвашла, Cymraeg, Dansk, Zazaki, ދިވެހިބަސް,
  Ελληνικά, Emiliàn e rumagnòl, English, Esperanto, Español, Eesti,
  Euskara, فارسی, Suomi, Võro, Føroyskt, Français, Arpetan, Furlan,
  Frysk, Gaeilge, 贛語, Gàidhlig, Galego, Avañe'ẽ, ગુજરાતી, Gaelg,
  עברית, हिन्दी, Fiji Hindi, Hrvatski, Kreyòl ayisyen, Magyar, Հայերեն,
  Interlingua, Bahasa Indonesia, Ilokano, Ido, Íslenska, Italiano,
  日本語, Lojban, Basa Jawa, ქართული, Kongo, Kalaallisut, ಕನ್ನಡ,
  한국어, Къарачай-Малкъар, Ripoarisch, Kurdî, Коми, Kernewek,
  Кыргызча, Latina, Ladino, Lëtzebuergesch, Limburgs, Lingála, ລາວ,
  Lietuvių, Latviešu, Basa Banyumasan, Malagasy, Македонски,
  മലയാളം, मराठी, مازِرونی, Bahasa Melayu, Nnapulitano, Nedersaksisch,
  नेपाल भाषा, Nederlands, ‪Norsk (nynorsk)‬, ‪Norsk (bokmål)‬, Nouormand,
  Diné bizaad, Occitan, Иронау, Papiamentu, Deitsch, Polski,
  پنجابی, پښتو, Norfuk / Pitkern, Português, Runa Simi, Rumantsch,
  Romani, Română, Русский, Саха тыла, Sardu, Sicilianu, Scots,
  Sámegiella, Simple English, Slovenčina, Slovenščina, Српски / Srpski,
  Seeltersk, Svenska, Kiswahili, தமிழ், తెలుగు, Тоҷикӣ, ไทย, Türkmençe,
  Tagalog, Türkçe, Татарча/Tatarça, Українська, اردو, Tiếng Việt,
  Volapük, Walon, Winaray, 吴语, isiXhosa, ייִדיש, Yorùbá, Zeêuws, 中文,
  Bân-lâm-gú, 粵語
  """

  setup_all do
    File.mkdir_p!(@tmp_dir)
    # Start up a Python server to test against
    py_output_dir = Path.join(@tmp_dir, "gen-py")
    ThriftTestHelpers.generate_thrift_files("py", @thrift_file_path, py_output_dir)
    port = ThriftTestHelpers.python([@py_server_path], py_output_dir)
    {:os_pid, os_pid} = Port.info(port, :os_pid)

    # Start up an Elixir client for tests
    @thrift_file_path
    |> parse_thrift
    |> compile_modules_to_dir(@tmp_dir)

    {:ok, client} = Client.start_link("localhost", 2345, [])

    on_exit fn ->
      # We can't simply use `Port.close` to kill the python process, as it will turn
      # into a zombie. Instead we use the kill command.
      {_, 0} = System.cmd("kill", [to_string(os_pid)])
      File.rm_rf!(@tmp_dir)
    end

    %{client: client}
  end

  test "testVoid", %{client: client} do
    assert {:ok, nil} = Client.test_void(client)
  end

  test "testString", %{client: client} do
    assert {:ok, "hello"} = Client.test_string(client, "hello")
    assert {:ok, ""} = Client.test_string(client, "")
    assert {:ok, @unicode_test_string1} = Client.test_string(client, @unicode_test_string1)
    assert {:ok, @unicode_test_string2} = Client.test_string(client, @unicode_test_string2)
  end

  test "testBool", %{client: client} do
    assert {:ok, true} = Client.test_bool(client, true)
    assert {:ok, false} = Client.test_bool(client, false)
  end

  test "testByte", %{client: client} do
    assert {:ok, 63} = Client.test_byte(client, 63)
    assert {:ok, -127} = Client.test_byte(client, -127)
  end

  test "testI32", %{client: client} do
    assert {:ok, -1} = Client.test_i32(client, -1)
    assert {:ok, 0} = Client.test_i32(client, 0)
  end

  test "testI64", %{client: client} do
    assert {:ok, 1} = Client.test_i64(client, 1)
    assert {:ok, -34359738368} = Client.test_i64(client, -34359738368)
  end

  test "testDouble", %{client: client} do
    assert {:ok, -5.235098235} = Client.test_double(client, -5.235098235)
    assert {:ok, 0.0} = Client.test_double(client, 0.0)
    assert {:ok, 0.0} = Client.test_double(client, 0.0)
    assert {:ok, -0.000341012439638598279} = Client.test_double(client, -0.000341012439638598279)
  end

  test "testBinary", %{client: client} do
    value = 0..255
      |> Enum.to_list
      |> :erlang.list_to_binary
    assert {:ok, ^value} = Client.test_binary(client, value)
  end

  test "testStruct", %{client: client} do
    {struct, []} = Code.eval_string("""
      %ThriftTest.Xtruct{
        string_thing: "Zero",
        byte_thing: 1,
        i32_thing: -3,
        i64_thing: -5}
    """)
    assert {:ok, ^struct} = Client.test_struct(client, struct)
  end

  test "testNest", %{client: client} do
    {struct, []} = Code.eval_string("""
      %ThriftTest.Xtruct2{
        struct_thing: %ThriftTest.Xtruct{
          string_thing: "Zero",
          byte_thing: 1,
          i32_thing: -3,
          i64_thing: -5},
        byte_thing: 0,
        i32_thing: 0
      }
    """)
    assert {:ok, ^struct} = Client.test_nest(client, struct)
  end

  test "testMap", %{client: client} do
    map = %{0 => 1, 1 => 2, 2 => 3, 3 => 4, -1 => -2}
    assert {:ok, ^map} = Client.test_map(client, map)
  end

  test "testSet", %{client: client} do
    set = MapSet.new([8, 1, 42])
    assert {:ok, ^set} = Client.test_set(client, set)
  end

  test "testList", %{client: client} do
    list = [1, 4, 9, -42]
    assert {:ok, ^list} = Client.test_list(client, list)
  end

  test "testEnum", %{client: client} do
    {value, []} = Code.eval_string("""
      require ThriftTest.Numberz
      ThriftTest.Numberz.five
    """)
    assert {:ok, ^value} = Client.test_enum(client, value)
  end

  test "testTypedef", %{client: client} do
    value = 0xffffffffffffff # 7 bytes of 0xff
    assert {:ok, ^value} = Client.test_typedef(client, value)
  end

  test "testMapMap", %{client: client} do
    map = %{
      -4 => %{-4 => -4, -3 => -3, -2 => -2, -1 => -1},
      4 => %{4 => 4, 3 => 3, 2 => 2, 1 => 1}
    }
    assert {:ok, ^map} = Client.test_map_map(client, 42)
  end

  test "testMulti", %{client: client} do
    {expected, []} = Code.eval_string("""
      %ThriftTest.Xtruct{
        string_thing: "Hello2",
        byte_thing: 74,
        i32_thing: 0xff00ff,
        i64_thing: 0xffffffffd0d0
      }
    """)
    {numberz5, []} = Code.eval_string("""
      require ThriftTest.Numberz
      ThriftTest.Numberz.five
    """)
    assert {:ok, ^expected} = Client.test_multi(client,
                                                expected.byte_thing,
                                                expected.i32_thing,
                                                expected.i64_thing,
                                                %{0 => "abc"},
                                                numberz5,
                                                0xf0f0f0)
  end

  test "testException", %{client: client} do
    {xception, []} = Code.eval_string("""
      %ThriftTest.Xception{
        error_code: 1001,
        message: "Xception"
      }
    """)
    assert {:ok, nil} = Client.test_exception(client, "Safe")
    assert {:error, {:exception, ^xception}} = Client.test_exception(client, "Xception")
    assert {:error, {:exception, %Thrift.TApplicationException{}}} = Client.test_exception(client, "TException")
    assert {:ok, nil} = Client.test_exception(client, "success")
  end

  test "testMultiException", %{client: client} do
    {xception, []} = Code.eval_string("""
      %ThriftTest.Xception{
        error_code: 1001,
        message: "This is an Xception"
      }
    """)
    {xception2, []} = Code.eval_string("""
      %ThriftTest.Xception2{
        error_code: 2002,
        struct_thing: %ThriftTest.Xtruct{string_thing: "This is an Xception2"}
      }
    """)
    {xtruct, []} = Code.eval_string("""
      %ThriftTest.Xtruct{
        string_thing: "foobar"
      }
    """)
    assert {:error, {:exception, ^xception}} = Client.test_multi_exception(client, "Xception", "ignore")
    assert {:error, {:exception, ^xception2}} = Client.test_multi_exception(client, "Xception2", "ignore")
    assert {:ok, ^xtruct} = Client.test_multi_exception(client, "success", "foobar")
  end

  test "testOneway", %{client: client} do
    start_time = System.os_time(:second)
    assert {:ok, nil} = Client.test_oneway(client, 1)
    end_time = System.os_time(:second)
    assert end_time - start_time < 3
  end

  test "testOnewayThenNormal", %{client: client} do
    assert {:ok, nil} = Client.test_oneway(client, 1)
    assert {:ok, "Elixir"} = Client.test_string(client, "Elixir")
  end
end

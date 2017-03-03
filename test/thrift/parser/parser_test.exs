defmodule Thrift.Parser.ParserTest do
  use ExUnit.Case, async: true

  @project_root Path.expand("../..", __DIR__)
  @test_file_dir Path.join([@project_root, "tmp", "parser_test"])

  import Thrift.Parser, only: [parse: 1, parse: 2, parse_file: 2]

  alias Thrift.Parser.Models.Constant
  alias Thrift.Parser.Models.Exception
  alias Thrift.Parser.Models.Field
  alias Thrift.Parser.Models.Function
  alias Thrift.Parser.Models.Include
  alias Thrift.Parser.Models.Namespace
  alias Thrift.Parser.Models.Schema
  alias Thrift.Parser.Models.Service
  alias Thrift.Parser.Models.Struct
  alias Thrift.Parser.Models.TypeRef
  alias Thrift.Parser.Models.TEnum
  alias Thrift.Parser.Models.Union
  alias Thrift.Parser.Models.ValueRef

  import ExUnit.CaptureIO

  setup_all do
    File.rm_rf!(@test_file_dir)
    File.mkdir_p!(@test_file_dir)
    on_exit fn -> File.rm_rf!(@test_file_dir) end
  end

  test "parsing comments" do
    {:ok, schema} = """
    // a simple C-style comment
    """
    |> parse

    assert schema == %Schema{}
  end

  test "parsing long-comments " do
    {:ok, schema} = """
    /* This is a long comment
    *  that spans many lines
    *  which means the docs are good
    *  aren't you happy?
    */
    """ |> parse

    assert schema == %Schema{}
  end

  test "parsing a single include header" do
    includes = """
    include "foo.thrift"
    """ |> parse([:includes])

    assert includes == [%Include{line: 1, path: "foo.thrift"}]
  end

  test "parsing namespace headers" do
    namespaces = """
    namespace py foo.bar.baz
    namespace erl foo_bar
    namespace * bar.baz
    """
    |> parse([:namespaces])

    assert namespaces[:py] == %Namespace{line: 1, name: :py, path: "foo.bar.baz"}
    assert namespaces[:erl] == %Namespace{line: 2, name: :erl, path: "foo_bar"}
    assert namespaces[:*] == %Namespace{line: 3, name: :*, path: "bar.baz"}
  end

  test "parsing include headers" do
    includes = """
    include "foo.thrift"
    include "bar.thrift"
    """
    |> parse([:includes])

    assert includes == [
      %Include{line: 1, path: "foo.thrift"},
      %Include{line: 2, path: "bar.thrift"}
    ]
  end

  test "parsing a byte constant" do
    constant = "const i8 BYTE_CONST = 2;"
    |> parse([:constants, :BYTE_CONST])

    assert constant == %Constant{line: 1,
                                 name: :BYTE_CONST,
                                 value: 2,
                                 type: :i8}
  end

  test "parsing a negative integer constant" do
    constant = "const i16 NEG_INT_CONST = -281;"
    |> parse([:constants, :NEG_INT_CONST])

    assert constant == %Constant{line: 1,
                                 name: :NEG_INT_CONST,
                                 value: -281,
                                 type: :i16}
  end

  test "parsing a small int constant" do
    constant = "const i16 SMALL_INT_CONST = 65535;"
    |> parse([:constants, :SMALL_INT_CONST])

    assert constant == %Constant{line: 1,
                                 name: :SMALL_INT_CONST,
                                 value: 65535,
                                 type: :i16}
  end

  test "parsing an int constant" do
    constant = "const i32 INT_CONST = 1234;"
    |> parse([:constants, :INT_CONST])

    assert constant == %Constant{line: 1,
                                 name: :INT_CONST,
                                 value: 1234,
                                 type: :i32}
  end

  test "parsing a large int constant" do
    constant = "const i64 LARGE_INT_CONST = 12347437812391;"
    |> parse([:constants, :LARGE_INT_CONST])

    assert constant == %Constant{line: 1,
                                 name: :LARGE_INT_CONST,
                                 value: 12347437812391,
                                 type: :i64}
  end

  test "parsing a double constant" do
    constant = "const double DOUBLE_CONST = 123.4"
    |> parse([:constants, :DOUBLE_CONST])

    assert constant == %Constant{line: 1,
                                 name: :DOUBLE_CONST,
                                 value: 123.4,
                                 type: :double}
  end

  test "parsing a string constant" do
    constant = "const string STRING_CONST = \"hi\""
    |> parse([:constants, :STRING_CONST])

    assert constant == %Constant{line: 1,
                                 name: :STRING_CONST,
                                 value: "hi",
                                 type: :string}
  end

  test "parsing a map constant" do
    constant = "const map<string, i32> MAP_CONST = {\"hello\": 1, \"world\": 2};"
    |> parse([:constants, :MAP_CONST])

    assert constant == %Constant{line: 1,
                                 name: :MAP_CONST,
                                 value: %{"world" => 2, "hello" => 1},
                                 type: {:map, {:string, :i32}}}
  end

  test "parsing a list constant" do
    constant = "const list<i32> LIST_CONST = [5, 6, 7, 8]"
    |> parse([:constants, :LIST_CONST])

    assert constant == %Constant{line: 1,
                                 name: :LIST_CONST,
                                 value: [5, 6, 7, 8],
                                 type: {:list, :i32}}
  end

  test "parsing a list constant with mixed separators" do
    constant = "const list<i32> LIST_CONST = [1, 2; 3; 4, 5]"
    |> parse([:constants, :LIST_CONST])

    assert constant == %Constant{line: 1,
                                 name: :LIST_CONST,
                                 value: [1, 2, 3, 4, 5],
                                 type: {:list, :i32}}
  end

  test "parsing an enum value constant" do
    constant = "const string SUNNY = Weather.SUNNY;"
    |> parse([:constants, :SUNNY])

    assert constant == %Constant{
      line: 1,
      name: :SUNNY,
      value: %ValueRef{line: 1, referenced_value: :"Weather.SUNNY"},
      type: :string}
  end

  test "parsing a list constant with enum values" do
    constant = """
    const list<string> WEATHER_TYPES = [
      Weather.SUNNY,
      Weather.CLOUDY,
      Weather.RAINY,
      Weather.SNOWY
    ]
    """
    |> parse([:constants, :WEATHER_TYPES])

    assert constant == %Constant{
      line: 1,
      name: :WEATHER_TYPES,
      type: {:list, :string},
      value: [
        %ValueRef{line: 2, referenced_value: :"Weather.SUNNY"},
        %ValueRef{line: 3, referenced_value: :"Weather.CLOUDY"},
        %ValueRef{line: 4, referenced_value: :"Weather.RAINY"},
        %ValueRef{line: 5, referenced_value: :"Weather.SNOWY"},
      ]}
  end

  test "parsing a map constant with enum keys" do
    constant = """
    const map<Weather, string> weather_messages = {
      Weather.SUNNY: "Yay, it's sunny!",
      Weather.CLOUDY: "Welcome to Cleveland!",
      Weather.RAINY: "Welcome to Seattle!",
      Weather.SNOWY: "Welcome to Canada!"
    }
    """
    |> parse([:constants, :weather_messages])

    assert constant == %Constant{
      line: 1,
      name: :weather_messages,
      type: {:map, {%TypeRef{line: 1, referenced_type: :Weather}, :string}},
      value: %{
        %ValueRef{line: 2, referenced_value: :"Weather.SUNNY"} => "Yay, it's sunny!",
        %ValueRef{line: 3, referenced_value: :"Weather.CLOUDY"} => "Welcome to Cleveland!",
        %ValueRef{line: 4, referenced_value: :"Weather.RAINY"} => "Welcome to Seattle!",
        %ValueRef{line: 5, referenced_value: :"Weather.SNOWY"} => "Welcome to Canada!"}}
  end

  test "parsing a map constant with enum values as values" do
    constant = """
    const map<string, Weather> clothes_to_wear = {
      "gloves": Weather.SNOWY,
      "umbrella": Weather.RAINY,
      "sweater": Weather.CLOUDY,
      "sunglasses": Weather.SUNNY
    }
    """
    |> parse([:constants, :clothes_to_wear])

    assert constant == %Constant{
      line: 1,
      name: :clothes_to_wear,
      type: {:map, {:string, %TypeRef{line: 1, referenced_type: :Weather}}},
      value: %{
        "gloves" => %ValueRef{line: 2, referenced_value: :"Weather.SNOWY"},
        "umbrella" => %ValueRef{line: 3, referenced_value: :"Weather.RAINY"},
        "sweater" => %ValueRef{line: 4, referenced_value: :"Weather.CLOUDY"},
        "sunglasses" => %ValueRef{line: 5, referenced_value: :"Weather.SUNNY"}}}
  end

  test "parsing an enum" do
    user_status = """
    enum UserStatus {
      ACTIVE,
      INACTIVE,
      BANNED = 6,
      EVIL = 0x20
    }
    """
    |> parse([:enums, :UserStatus])

    assert user_status == %TEnum{line: 1,
                                 name: :UserStatus,
                                 values: [ACTIVE: 1, INACTIVE: 2, BANNED: 6, EVIL: 32]}
  end

  test "parsing an exception" do
    program = """
    exception ApplicationException {
      1: string message,
      2: required i32 count,
      3: optional string reason
      optional string other;
      optional string fixed = "foo"
    }
    """

    warnings = capture_io(fn ->
      exc = parse(program, [:exceptions, :ApplicationException])

      assert exc == %Exception{
        line: 1,
        name: :ApplicationException,
        fields: [
          %Field{line: 2, id: 1, name: :message, type: :string},
          %Field{line: 3, id: 2, name: :count, type: :i32, required: true},
          %Field{line: 4, id: 3, name: :reason, type: :string, required: false},
          %Field{line: 5, id: -1, name: :other, type: :string, required: false},
          %Field{line: 6, id: -2, name: :fixed, type: :string, required: false, default: "foo"}
        ]}
    end)

    assert warnings =~ ~s("other" is missing an explicit field identifier)
    assert warnings =~ ~s("fixed" is missing an explicit field identifier)
  end

  test "an exception with duplicate ids" do
    program = """
    exception BadEx {
     1: optional string bad,
     1: optional string evil;
    }
    """

    expected_error = "Error: BadEx.bad, BadEx.evil share field number 1."
    assert_raise RuntimeError, expected_error, fn ->
      parse(program)
    end
  end

  test "parsing a typedef" do
    typedefs = """
    typedef i64 id
    typedef string json
    typedef list<string> string_list
    """
    |> parse([:typedefs])

    assert typedefs[:id] == :i64
    assert typedefs[:string_list] == {:list, :string}
  end

  test "parsing a struct with a bool" do
    s = """
    struct MyStruct {
      1: optional bool negative;
      2: optional bool positive = true;
      3: optional bool c_positive = 1;
      4: optional bool c_negative = 0;
    }
    """
    |> parse([:structs, :MyStruct])

    assert s == %Struct{
      line: 1,
      name: :MyStruct,
      fields: [
        %Field{line: 2, id: 1, name: :negative, type: :bool, required: false, default: nil},
        %Field{line: 3, id: 2, name: :positive, type: :bool, required: false, default: true},
        %Field{line: 4, id: 3, name: :c_positive, type: :bool, required: false, default: true},
        %Field{line: 5, id: 4, name: :c_negative, type: :bool, required: false, default: false},
      ]}
  end

  test "parsing a struct with an int" do
    s = """
    struct MyStruct {
      1: optional string name;
    }
    """
    |> parse([:structs, :MyStruct])

    assert s == %Struct{
      line: 1,
      name: :MyStruct,
      fields: [
        %Field{line: 2, id: 1, name: :name, type: :string, required: false}
      ]}
  end

  test "parsing a struct with a typedef" do
    s = """
    typedef i64 id

    struct User {
      1: required id user_id,
      2: required string username
    }
    """ |> parse([:structs, :User])

    assert s.fields == [
      %Field{line: 4, id: 1, name: :user_id, required: true, type: %TypeRef{line: 4, referenced_type: :id}},
      %Field{line: 5, id: 2, name: :username, required: true, type: :string}
    ]
  end

  test "parsing a struct with optional things removed" do
    struct_def = """
    struct Optionals {
      string name
      i32 count,
      i64 long_thing = 12345
      optional list<i32> optional_list,
    }
    """

    warnings = capture_io(fn ->
      s = parse(struct_def, [:structs, :Optionals])

      assert s == %Struct{
        line: 1,
        name: :Optionals,
        fields: [
          %Field{line: 2, id: -1, name: :name, type: :string, required: :default},
          %Field{line: 3, id: -2, name: :count, type: :i32, required: :default},
          %Field{line: 4, id: -3, name: :long_thing, type: :i64, required: :default, default: 12345},
          %Field{line: 5, id: -4, name: :optional_list, type: {:list, :i32}, required: false}
        ]
      }
    end)

    [:name, :count, :long_thing, :optional_list]
    |> Enum.each(fn name ->
      assert warnings =~ ~s("#{name}" is missing an explicit field identifier)
    end)
  end

  test "parsing an empty map default value" do
    struct = """
    struct EmptyDefault {
      1: i64 id,
      2: map<string, string> myMap={},
    }
    """
    |> parse([:structs, :EmptyDefault])

    assert struct == %Struct{
      line: 1,
      name: :EmptyDefault,
      fields: [
        %Field{line: 2, default: nil, id: 1, name: :id, required: :default, type: :i64},
        %Field{line: 3, default: %{}, id: 2, name: :my_map,
               required: :default, type: {:map, {:string, :string}}}
      ]}
  end

  test "when default ids conflict with explicit ids" do

    assert_raise RuntimeError, fn ->
      capture_io fn ->
        """
        struct BadFields {
          1: required i32 first,
          1: optional i64 other
        }
        """ |> parse
      end
    end
  end

  test "when a struct has another struct as a member" do
    user = """
    struct Name {
      1: string first_name,
      2: string last_name
    }

    struct User {
       1: i64 id,
       2: Name name,
    }
    """ |> parse([:structs, :User])
    assert user == %Struct{
      line: 6,
      name: :User,
      fields: [
        %Field{line: 7, id: 1, type: :i64, name: :id},
        %Field{line: 8, id: 2, type: %TypeRef{line: 8, referenced_type: :Name}, name: :name}
      ]
    }
  end

  test "parsing a union definition" do
    union = """
    union Highlander {
      1: i32 connery,
      2: i64 lambert
    }
    """
    |> parse([:unions, :Highlander])

    assert union == %Union{
      line: 1,
      name: :Highlander,
      fields: [
        %Field{line: 2, id: 1, name: :connery, type: :i32, required: false},
        %Field{line: 3, id: 2, name: :lambert, type: :i64, required: false},
      ]
    }
  end

  test "a union definition makes sure its field ids aren't repeated" do
    capture_io fn ->
      assert_raise RuntimeError, fn ->
      """
        union Highlander {
          1: i32 connery,
          1: i64 lambert
        }
      """
      |> parse
      end

    end
  end

  test "defining a simple service" do
    service = """
    service MyService {
      void hi()
    }
    """
    |> parse([:services, :MyService])

    assert service == %Service{
      line: 1,
      name: :MyService,
      functions: %{hi: %Function{line: 2, name: :hi, return_type: :void, params: []}}
    }
  end

  test "defining a service with a complex return type and params" do
    service = """
    struct User {
    }

    service MyService {
       map<string, i64> usernames_to_ids(1: User user)
    }
    """
    |> parse([:services, :MyService])

    assert service == %Service{
      line: 4,
      name: :MyService,
      functions: %{usernames_to_ids:
        %Function{line: 5, name: :usernames_to_ids, oneway: false, return_type: {:map, {:string, :i64}},
                  params: [%Field{line: 5, id: 1, name: :user, type: %TypeRef{line: 5, referenced_type: :User}}]
                 }
      }
    }
  end

  test "a oneway function in a service" do
    service = """
    service OneWay {
      oneway void fireAndForget(1: i64 value);
    }
    """
    |> parse([:services, :OneWay])

    assert service == %Service{
      line: 1,
      name: :OneWay,
      functions: %{
        fireAndForget: %Function{
          line: 2,
          name: :fireAndForget, oneway: true, return_type: :void,
          params: [
            %Field{line: 2, id: 1, name: :value, type: :i64}
          ]
        }
      }
    }
  end

  test "a service that throws exceptions" do
    service = """
    exception ServiceException {
      1: i32 error_code = 0,
      2: string reason = "Unknown"
    }

    service Thrower {
       oneway void blowup() throws (1: ServiceException svc)
    }
    """
    |> parse([:services, :Thrower])

    %{blowup: function} = service.functions
    assert function.exceptions == [
      %Field{line: 7, id: 1, name: :svc, type: %TypeRef{line: 7, referenced_type: :ServiceException}}
    ]
  end

  test "a service with several functions" do
    code = """
    struct User {
      1: i64 id,
      2: string username
    }

    exception ServiceException {
      1: string message
      2: i32 code
    }

    service MultipleFns {
       void ping(),
       oneway void update(1: i64 user_id, string field, string value),
       map<i64, User> get_users(1: set<i64> user_ids) throws (1: ServiceException svc)
    }
    """
    capture_io fn ->
      service = parse(code, [:services, :MultipleFns])

      %{ping: ping, update: update, get_users: get_users} = service.functions

      assert ping == %Function{line: 12, name: :ping}
      assert update == %Function{
        line: 13,
        oneway: true,
        name: :update,
        params: [
          %Field{line: 13, id: 1, name: :user_id, type: :i64},
          %Field{line: 13, id: -1, name: :field, type: :string},
          %Field{line: 13, id: -2, name: :value, type: :string}
        ]
      }
      assert get_users == %Function{
        line: 14,
        name: :get_users,
        exceptions: [
          %Field{line: 14, id: 1, name: :svc, type: %TypeRef{line: 14, referenced_type: :ServiceException}}
        ],
        params: [
          %Field{line: 14, id: 1, name: :user_ids, type: {:set, :i64}},
        ],
        return_type: {:map, {:i64, %TypeRef{line: 14, referenced_type: :User}}}
      }
    end
  end

  test "a service extends another" do
    services = """
    service Pinger {
      boolean ping()
    }

    service Extender extends Pinger {
      boolean is_ready()
    }
    """
    |> parse([:services])

    assert services[:Extender].extends == :Pinger
  end

  test "parsing a real thrift file" do
    # just make sure we don't blow up on parse and can parse
    # complex thrift files.

    File.read!("./test/fixtures/app/thrift/ThriftTest.thrift")
    |> parse
  end

  test "name collisions in the same type and thrift file" do
    thrift = """
    struct Foo {}
    struct Foo {}
    """

    assert_raise RuntimeError, "Name collision: Foo", fn ->
      parse(thrift)
    end
  end

  test "namespace option can be a string or atom" do
    contents = """
    struct GetNamespaced {
      1: i32 id
    }
    """

    path = Path.join(@test_file_dir, "get_namespaced.thrift")
    File.write!(path, contents)

    result = parse_file(path, namespace: "WithNamespace")
    assert "WithNamespace" == result.ns_mappings.get_namespaced.path

    result = parse_file(path, namespace: WithNamespace)
    assert "WithNamespace" == result.ns_mappings.get_namespaced.path

    result = parse_file(path, namespace: "with_namespace")
    assert "WithNamespace" == result.ns_mappings.get_namespaced.path

    result = parse_file(path, namespace: :with_namespace)
    assert "WithNamespace" == result.ns_mappings.get_namespaced.path
  end
end
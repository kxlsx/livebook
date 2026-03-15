defmodule Livebook.Intellisense.ErlangTest do
  use ExUnit.Case, async: true

  import Livebook.TestHelpers

  alias Livebook.Intellisense

  setup do
    Intellisense.clear_cache(node())
    :ok
  end

  describe "details" do
    test "returns nil if there are no matches" do
      context = intellisense_context_from_eval(do: nil)

      assert nil ==
               Intellisense.Erlang.handle_request(
                 {:details, "unknown:function()", 2},
                 context,
                 node()
               )
    end

    test "returns subject range" do
      context = intellisense_context_from_eval(do: nil)

      assert %{range: %{from: 1, to: 10}} =
               Intellisense.Erlang.handle_request(
                 {:details, "lists:map(F, L)", 8},
                 context,
                 node()
               )

      assert %{range: %{from: 1, to: 6}} =
               Intellisense.Erlang.handle_request(
                 {:details, "lists:map(F, L)", 2},
                 context,
                 node()
               )
    end

    test "returns details only for exactly matching identifiers" do
      context = intellisense_context_from_eval(do: nil)

      assert nil ==
               Intellisense.Erlang.handle_request({:details, "lists:ma", 6}, context, node())
    end

    test "returns full docs for standard library modules" do
      context = intellisense_context_from_eval(do: nil)

      assert %{contents: [content]} =
               Intellisense.Erlang.handle_request({:details, "lists:map", 7}, context, node())

      assert content =~ "Apply function" or content =~ "function"
    end

    test "returns deprecated docs" do
      context = intellisense_context_from_eval(do: nil)

      assert %{contents: [content | _]} =
               Intellisense.Erlang.handle_request({:details, "erlang:now", 8}, context, node())

      assert content =~ "deprecated" or content =~ "Do not use"
    end

    test "properly parses unicode in strings" do
      context = intellisense_context_from_eval(do: nil)

      assert nil ==
               Intellisense.Erlang.handle_request({:details, "Msg = \"🍵\"", 8}, context, node())
    end

    test "handles local calls (BIFs and imported)" do
      context = intellisense_context_from_eval(do: nil)

      assert %{contents: [length_fn]} =
               Intellisense.Erlang.handle_request({:details, "length([1])", 3}, context, node())

      assert length_fn =~ "Returns the length"
    end

    test "returns nil for binary syntax modifiers" do
      context = intellisense_context_from_eval(do: nil)

      assert nil ==
               Intellisense.Erlang.handle_request(
                 {:details, "<<X/integer>>", 6},
                 context,
                 node()
               )
    end

    test "includes full module name in the docs" do
      context = intellisense_context_from_eval(do: nil)

      assert %{contents: [lists_doc]} =
               Intellisense.Erlang.handle_request({:details, "lists", 4}, context, node())

      assert lists_doc =~ "lists"
    end

    test "returns module-prepended type signatures" do
      context = intellisense_context_from_eval(do: nil)

      assert %{contents: contents} =
               Intellisense.Erlang.handle_request(
                 {:details, "erlang:timestamp", 8},
                 context,
                 node()
               )

      assert Enum.any?(contents, &(&1 =~ "-type timestamp()"))
    end

    test "includes type specs (opaque and regular)" do
      context = intellisense_context_from_eval(do: nil)

      # Type spec for function
      assert %{contents: [spec]} =
               Intellisense.Erlang.handle_request({:details, "lists:map", 8}, context, node())

      assert spec =~ "-spec map"

      assert %{contents: contents} =
               Intellisense.Erlang.handle_request(
                 {:details, "gb_sets:set", 9},
                 context,
                 node()
               )

      assert Enum.any?(contents, fn c -> c =~ "-opaque set()" or c =~ "-type set()" end)
    end

    test "returns link to online documentation" do
      context = intellisense_context_from_eval(do: nil)

      # Erlang module
      assert %{contents: [content]} =
               Intellisense.Erlang.handle_request({:details, "lists", 3}, context, node())

      assert content =~ ~r"https://www.erlang.org/doc/(?:man|apps)(?:/[a-z_]+)?/lists.html"

               # Erlang function
      assert %{contents: [content]} =
               Intellisense.Erlang.handle_request(
                 {:details, "lists:map", 8},
                 context,
                 node()
               )

      assert content =~ ~r"https://www.erlang.org/doc/(?:man|apps)(?:/[a-z_]+)?/lists.html#map-2"
    end

    @tag :tmp_dir
    test "includes definition location for runtime modules with debug_info", %{tmp_dir: tmp_dir} do
      context = intellisense_context_from_eval(tmp_dir, do: nil)

      erlang_source = """
      -module(test_goto_def).
      -export([hello/1]).
      -export_type([my_type/0]).

      -type my_type() :: integer().

      -spec hello(any()) -> ok.
      hello(_Msg) -> ok.
      """

      erl_file = Path.join(tmp_dir, "test_goto_def.erl")
      File.write!(erl_file, erlang_source)

      {:ok, module, binary} = :compile.file(String.to_charlist(erl_file), [:debug_info, :binary])

      beam_file = Path.join(tmp_dir, "#{module}.beam")
      File.write!(beam_file, binary)

      :code.load_binary(module, String.to_charlist(beam_file), binary)

      assert %{definition: %{line: 1, file: ^erl_file}} =
               Intellisense.Erlang.handle_request(
                 {:details, "test_goto_def", 5},
                 context,
                 node()
               )

      assert %{definition: %{line: 5, file: ^erl_file}} =
               Intellisense.Erlang.handle_request(
                 {:details, "test_goto_def:my_type", 18},
                 context,
                 node()
               )

      assert %{definition: %{line: 8, file: ^erl_file}} =
               Intellisense.Erlang.handle_request(
                 {:details, "test_goto_def:hello", 18},
                 context,
                 node()
               )
    end
  end
end
defmodule Livebook.Intellisense.ErlangTest do
  use ExUnit.Case, async: true

  import Livebook.TestHelpers

  alias Livebook.Intellisense

  setup do
    Intellisense.clear_cache(node())
    :ok
  end

  # describe "completion" do
    # test "template" do
    #   context = intellisense_context_from_eval(do: nil)

    #   assert %{
    #     items: [
    #       %{
    #         label: "",
    #         kind: :module,
    #         documentation: """
    #         """,
    #         insert_text: ""
    #       }
    #     ]
    #   } = Intellisense.Erlang.handle_request({:completion, ""}, context, node())
    # end

    # test "completion when no hint given" do
    #   context = intellisense_context_from_eval(do: nil)

    #   length_item = %{
    #     label: "length/1",
    #     kind: :function,
    #     documentation: """
    #     Returns the length of `list`.

    #     ```
    #     Kernel.length(list)
    #     ```\
    #     """,
    #     insert_text: "length(${})"
    #   }

    #   assert %{items: items} =
    #            Intellisense.Elixir.handle_request({:completion, ""}, context, node())

    #   assert length_item in items

    #   assert %{items: items} =
    #            Intellisense.Elixir.handle_request({:completion, "to_string("}, context, node())

    #   assert length_item in items

    #   assert %{items: items} =
    #            Intellisense.Elixir.handle_request(
    #              {:completion, "Enum.map(list, "},
    #              context,
    #              node()
    #            )

    #   assert length_item in items
    # end

    test "handle basic module completion" do
      context = intellisense_context_from_eval(do: nil)

      erlang_module = %{
        label: "erlang",
        kind: :module,
        documentation: "The Erlang BIFs and predefined types.\n\n(module)",
        insert_text: "erlang"
      }

      assert %{items: items} =
               Intellisense.Erlang.handle_request({:completion, "e"}, context, node())

      assert erlang_module in items

      assert %{items: items} =
               Intellisense.Erlang.handle_request({:completion, "erl"}, context, node())

      assert erlang_module in items

      assert %{items: items} =
               Intellisense.Erlang.handle_request({:completion, "erlan"}, context, node())

      assert erlang_module in items
    end

    test "module completion with self" do
      context = intellisense_context_from_eval(do: nil)

      assert %{
               items: [
                 %{
                    label: "erlang",
                    kind: :module,
                    documentation: "The Erlang BIFs and predefined types.\n\n(module)",
                    insert_text: "erlang"
                  }
               ]
             } = Intellisense.Erlang.handle_request({:completion, "erlang"}, context, node())
    end

    test "module multiple values completion" do
      context = intellisense_context_from_eval(do: nil)

      assert %{
               items: [
                 %{
                   label: "erl_ddll",
                   kind: :module,
                   documentation: _erl_ddl_doc,
                   insert_text: "erl_ddll"
                 },
                 %{
                   label: "erl_debugger",
                   kind: :module,
                   documentation: _erl_debugger_doc,
                   insert_text: "erl_debugger"
                 }
               ]
             } = Intellisense.Erlang.handle_request({:completion, "erl_d"}, context, node())
    end

    test "whitespace does not matter" do
      context = intellisense_context_from_eval(do: nil)

      lists_item = %{
        label: "lists",
        kind: :module,
        documentation: """
        List processing functions.

        (module)\
        """,
        insert_text: "lists"
      }

      assert %{items: items} =
               Intellisense.Erlang.handle_request({:completion, "l"}, context, node())

      assert lists_item in items

      assert %{items: items} =
               Intellisense.Erlang.handle_request({:completion, "  l"}, context, node())

      assert lists_item in items
    end

    test "completion doesn't include quoted atoms" do
      context = intellisense_context_from_eval(do: nil)

      assert %{items: []} =
               Intellisense.Erlang.handle_request({:completion, ~s{Elixir}}, context, node())
    end

    test "module completion with 'in' operator in spec" do
      context = intellisense_context_from_eval(do: nil)

      assert %{
        items: [
          %{
            label: "open_port/2",
            kind: :function,
                   documentation: _open_port_doc,
                   insert_text: "open_port(${})"
                 }
                ]
                } =
                  Intellisense.Erlang.handle_request(
                    {:completion, "erlang.open_por"},
                    context,
                    node()
                    )
                  end

    test "type completion" do
      context = intellisense_context_from_eval(do: nil)

      assert %{items: items} =
               Intellisense.Erlang.handle_request(
                 {:completion, "maps:iterator"},
                 context,
                 node()
               )

      assert %{
               label: "iterator/0",
               kind: :type,
               documentation: """
               No documentation available

               ```
               @type iterator() :: iterator(term(), term())
               ```\
               """,
               insert_text: "iterator()"
             } in items

      assert %{
               label: "iterator/2",
               kind: :type,
               documentation: """
               An iterator representing the associations in a map with keys of type `Key` and
               values of type `Value`.

               ```
               @opaque iterator(key, value)
               ```\
               """,
               insert_text: "iterator(${})"
             } in items
    end

    test "Elixir proxy" do
      context = intellisense_context_from_eval(do: nil)

      assert %{items: items} =
               Intellisense.Erlang.handle_request({:completion, "eli"}, context, node())

      assert %{
               label: "elixir",
               kind: :module,
               documentation: """
               No documentation available

               (module)\
               """,
               insert_text: "elixir"
             } in items
    end

  test "basic directives completion" do
      context = intellisense_context_from_eval(do: nil)

      assert %{items: [
            %{
               label: "module",
               kind: :module_attribute,
               documentation: """


               (module attribute)\
               """,
               insert_text: "module(${})."
            },
            %{
               label: "moduledoc",
               kind: :module_attribute,
               documentation: """


               (module attribute)\
               """,
               insert_text: "moduledoc(${})."
             }
      ]} = Intellisense.Erlang.handle_request({:completion, "-m"}, context, node())
    end

  test "nonexistent directives completion" do
      context = intellisense_context_from_eval(do: nil)

      assert %{items: []} = Intellisense.Erlang.handle_request({:completion, "-unknown"}, context, node())
  end

  test "already finished modules" do
      context = intellisense_context_from_eval(do: nil)

      assert %{items: [
            %{
               label: "moduledoc",
               kind: :module_attribute,
               documentation: """


               (module attribute)\
               """,
               insert_text: "moduledoc(${})."
            }
      ]} = Intellisense.Erlang.handle_request({:completion, "-moduledoc"}, context, node())
    end

  test "empty module directive shows all" do
    context = intellisense_context_from_eval(do: nil)

    assert %{items: items} = Intellisense.Erlang.handle_request({:completion, "-"}, context, node())


    assert %{label: "moduledoc",
              kind: :module_attribute,
              documentation: """


              (module attribute)\
              """,
              insert_text: "moduledoc(${})."} in items

    assert %{label: "behaviour",
              kind: :module_attribute,
              documentation: """


              (module attribute)\
              """,
              insert_text: "behaviour(${})."} in items

    assert %{label: "nifs",
              kind: :module_attribute,
              documentation: """


              (module attribute)\
              """,
              insert_text: "nifs([${}])."} in items
  end
end

defmodule Livebook.Intellisense.Erlang do
  alias Livebook.Intellisense

  @behaviour Intellisense

  # Configures width used for inspect and specs formatting.
  @line_length 45

  @impl true
  def handle_request({:format, _code}, _context, _node) do
    # Not supported.
    nil
  end

  def handle_request({:completion, hint}, context, node) do
    handle_completion(hint, context, node)
  end

  def handle_request({:details, line, column}, context, _node) do
    handle_details(line, column, context)
  end

  def handle_request({:signature, hint}, context, _node) do
    handle_signature(hint, context)
  end

  defp handle_completion(hint, context, node) do
    items =
      Intellisense.Erlang.IdentifierMatcher.completion_identifiers(hint, context, node)
#      |> Enum.filter(&include_in_completion?/1)
      |> Enum.map(&format_completion_item/1)
#      |> Enum.concat(extra_completion_items(hint))
#      |> Enum.sort_by(&completion_item_priority/1)

    %{items: items}
  end

  defp format_completion_item(%{
    kind: :function,
    module: module,
    name: name,
    arity: arity,
    type: type,
    display_name: display_name,
    documentation: documentation,
    signatures: signatures
  }),
       do: %{
         label: "#{display_name}/#{arity}",
         kind: :function,
         documentation:
           join_with_newlines([
             Intellisense.Elixir.Docs.format_documentation(documentation, :short),
             code(format_signatures(signatures, module, name, arity))
           ]),
         insert_text:
           cond do
             type == :macro and keyword_macro?(name) ->
               "#{display_name} "

             type == :macro and env_macro?(name) ->
               display_name

             String.starts_with?(display_name, "~") ->
               display_name

             Macro.operator?(name, arity) ->
               display_name

             arity == 0 ->
               "#{display_name}()"

             true ->
               # A snippet with cursor in parentheses
               "#{display_name}(${})"
           end
       }

  defp format_completion_item(%{
    kind: :type,
    name: name,
    arity: arity,
    documentation: documentation,
    type_spec: type_spec
  }),
       do: %{
         label: "#{name}/#{arity}",
         kind: :type,
         documentation:
           join_with_newlines([
             Intellisense.Elixir.Docs.format_documentation(documentation, :short),
             format_type_spec(type_spec, @line_length) |> code()
           ]),
         insert_text:
           cond do
             arity == 0 -> "#{Atom.to_string(name)}()"
             true -> "#{Atom.to_string(name)}(${})"
           end
       }

  defp keyword_macro?(name) do
    def? = name |> Atom.to_string() |> String.starts_with?("def")

    def? or
    name in [
      # Special forms
      :alias,
      :case,
      :cond,
      :for,
      :fn,
      :import,
      :quote,
      :receive,
      :require,
      :try,
      :with,

      # Kernel
      :destructure,
      :raise,
      :reraise,
      :if,
      :unless,
      :use
    ]
  end

  defp env_macro?(name) do
    name in [:__ENV__, :__MODULE__, :__DIR__, :__STACKTRACE__, :__CALLER__]
  end

  defp join_with_newlines(strings), do: join_with(strings, "\n\n")

  defp join_with(strings, joiner) do
    case Enum.reject(strings, &is_nil/1) do
      [] -> nil
      parts -> Enum.join(parts, joiner)
    end
  end

  defp code(nil), do: nil

  defp code(code) do
    """
    ```
    #{code}
    ```\
    """
  end

  defp format_signatures([], module, name, arity) do
    signature_fallback(module, name, arity)
  end

  defp format_signatures(signatures, module, _name, _arity) do
    signatures_string = Enum.join(signatures, "\n")

    # Don't add module prefix to operator signatures
    if :binary.match(signatures_string, ["(", "/"]) != :nomatch do
      inspect(module) <> "." <> signatures_string
    else
      signatures_string
    end
  end

  defp signature_fallback(module, name, arity) do
    args = Enum.map_join(1..arity//1, ", ", fn n -> "arg#{n}" end)
    "#{inspect(module)}.#{name}(#{args})"
  end

  defp format_type_spec({type_kind, type}, line_length) when type_kind in [:type, :opaque] do
    ast = {:"::", _env, [lhs, _rhs]} = Code.Typespec.type_to_quoted(type)

    type_string =
      case type_kind do
        :type -> ast
        :opaque -> lhs
      end
      |> Macro.to_string()

    type_spec_code = "@#{type_kind} #{type_string}"

    try do
      Code.format_string!(type_spec_code, line_length: line_length)
    rescue
      _ -> type_spec_code
    end
  end

  defp format_type_spec(_, _line_length), do: nil

  defp handle_details(_line, _column, _context) do
    # TODO: implement. See t:Livebook.Runtime.details_response/0 for return type.
    nil
  end

  defp handle_signature(_hint, _context) do
    # TODO: implement. See t:Livebook.Runtime.signature_response/0 for return type.
    nil
  end
end

defmodule Livebook.Intellisense.Erlang.IdentifierMatcher do
  alias Livebook.Intellisense
  alias Livebook.Intellisense.Elixir.Docs

  @typedoc """
  A single identifier together with relevant information.
  """
  @type identifier_item ::
          %{
            kind: :variable,
            name: name()
          }
          | %{
              kind: :map_field,
              name: name()
            }
          | %{
              kind: :in_map_field,
              name: name()
            }
            | %{
                kind: :in_struct_field,
                module: module(),
                name: name(),
                default: term()
              }
            | %{
                kind: :module,
                module: module(),
                display_name: display_name(),
                documentation: Docs.documentation()
              }
              | %{
                  kind: :function,
                  module: module(),
                  name: name(),
                  arity: arity(),
                  type: :function | :macro,
                  display_name: display_name(),
                  from_default: boolean(),
                  documentation: Docs.documentation(),
                  signatures: list(Docs.signature()),
                  specs: list(Docs.spec()),
                  meta: Docs.meta()
                }
              | %{
                  kind: :type,
                  module: module(),
                  name: name(),
                  arity: arity(),
                  documentation: Docs.documentation(),
                  type_spec: Docs.type_spec()
                }
                | %{
                    kind: :module_attribute,
                    name: name(),
                    documentation: Docs.documentation()
                  }
                | %{
                    kind: :bitstring_modifier,
                    name: name(),
                    arity: integer()
                  }

  @type name :: atom()
  @type display_name :: String.t()

  @prefix_matcher &String.starts_with?/2

  @doc """
  Returns a list of identifiers matching the given `hint` together
  with relevant information.

  Evaluation binding and environment is used to expand aliases,
  imports, nested maps, etc.

  `hint` may be a single token or line fragment like `if Enum.m`.
  """
  @spec completion_identifiers(String.t(), Intellisense.context(), node()) ::
          list(identifier_item())
  def completion_identifiers(hint, intellisense_context, node) do
    context = cursor_context(hint)

    ctx = %{
      fragment: hint,
      intellisense_context: intellisense_context,
      matcher: @prefix_matcher,
      type: :completion,
      node: node
    }

    context_to_matches(context, ctx)
  end

  defp cursor_context(hint) do
    tokens =
      hint
      |> String.to_charlist()
      |> :erl_scan.string()

    case tokens do
      {:ok, token_list, _} ->
        categorize_tokens(token_list)
      _ ->
        :none
    end
  end

  defp categorize_tokens(tokens) do
    case Enum.reverse(tokens) do
      [{:":", _}, {:atom, _, module} | _rest] ->
        {:colon, module, "" }
      [{:atom, _, hint}, {:":", _}, {:atom, _, module} | _rest] ->
        {:colon, module, hint}
      _ ->
        :none
    end
  end

  defp context_to_matches(context, ctx) do
    case context do
      {:colon, mod, hint} ->
          match_module_member(mod, hint, ctx)
      # :none
      _ ->
        []
    end
  end

  defp match_module_member(mod, hint, ctx) do
    match_module_function(mod, hint, ctx) ++ match_module_type(mod, hint, ctx)
  end

  defp match_module_function(mod, hint, ctx, funs \\ nil) do
    if ensure_loaded?(mod, ctx.node) do
      funs = funs || exports(mod, ctx.node)

      matching_funs =
        Enum.filter(funs, fn {name, _arity, _type} ->
          name = Atom.to_string(name)
          ctx.matcher.(name, hint)
        end)

      doc_items =
        Intellisense.Elixir.Docs.lookup_module_members(
          mod,
          Enum.map(matching_funs, &Tuple.delete_at(&1, 2)),
          ctx.node,
          kinds: [:function, :macro]
        )

      Enum.map(matching_funs, fn {name, arity, type} ->
        doc_item =
          Enum.find(
            doc_items,
            %{from_default: false, documentation: nil, signatures: [], specs: [], meta: %{}},
            fn doc_item ->
              doc_item.name == name && doc_item.arity == arity
            end
          )

        %{
          kind: :function,
          module: mod,
          name: name,
          arity: arity,
          type: type,
          display_name: Atom.to_string(name),
          from_default: doc_item.from_default,
          documentation: doc_item.documentation,
          signatures: doc_item.signatures,
          specs: doc_item.specs,
          meta: doc_item.meta
        }
      end)
    else
      []
    end
  end

  defp exports(mod, node) do
    try do
      :erpc.call(node, mod, :module_info, [:exports])
    rescue
      _ -> []
    else
      exports ->
        for {fun, arity} <- exports,
            not reflection?(fun, arity) do
          {fun, arity, :function}
    end
  end
  end

  defp reflection?(:module_info, 0), do: true
  defp reflection?(:module_info, 1), do: true
  defp reflection?(:__info__, 1), do: true
  defp reflection?(_, _), do: false

  defp match_module_type(mod, hint, ctx) do
    types = get_module_types(mod, ctx.node)

    matching_types =
      Enum.filter(types, fn {name, _arity} ->
        name = Atom.to_string(name)
        ctx.matcher.(name, hint)
      end)

    doc_items =
      Intellisense.Elixir.Docs.lookup_module_members(mod, matching_types, ctx.node,
        kinds: [:type]
      )

    Enum.map(matching_types, fn {name, arity} ->
      doc_item =
        Enum.find(doc_items, %{documentation: nil, type_spec: nil}, fn doc_item ->
          doc_item.name == name && doc_item.arity == arity
        end)

      %{
        kind: :type,
        module: mod,
        name: name,
        arity: arity,
        documentation: doc_item.documentation,
        type_spec: doc_item.type_spec
      }
    end)
  end

  defp get_module_types(mod, node) do
    with true <- ensure_loaded?(mod, node),
         {:ok, types} <- :erpc.call(node, Code.Typespec, :fetch_types, [mod]) do
      for {kind, {name, _, args}} <- types, kind in [:type, :opaque] do
        {name, length(args)}
      end
    else
      _ -> []
    end
  end

  # Remote nodes only have loaded modules
  defp ensure_loaded?(_mod, node) when node != node(), do: true
  defp ensure_loaded?(mod, _node), do: Code.ensure_loaded?(mod)
end
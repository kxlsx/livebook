defmodule Livebook.Intellisense.Erlang.IdentifierMatcher do
  # This module allows for extracting information about identifiers
  # based on code and runtime information (binding, environment).
  #
  # This functionality is a basic building block to be used for code
  # completion and information extraction.
  #
  # The implementation is based primarily on `IEx.Autocomplete`. It
  # also takes insights from `ElixirSense.Providers.Suggestion.Complete`,
  # which is a very extensive implementation used in the Elixir Language
  # Server.

  alias GenLSP.Structures.LinkedEditingRangeRegistrationOptions
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

  @exact_matcher &Kernel.==/2
  @prefix_matcher &String.starts_with?/2

  @bitstring_modifiers [
    {:big, 0},
    {:binary, 0},
    {:bitstring, 0},
    {:integer, 0},
    {:float, 0},
    {:little, 0},
    {:native, 0},
    {:signed, 0},
    {:size, 1},
    {:unit, 1},
    {:unsigned, 0},
    {:utf8, 0},
    {:utf16, 0},
    {:utf32, 0}
  ]

  @alias_only_atoms ~w(alias import require)a
  @alias_only_charlists ~w(alias import require)c

  @doc """
  Clears all loaded entries stored for node.
  """
  def clear_all_loaded(node) do
    :persistent_term.erase({__MODULE__, node})
  end

  defp cached_all_loaded(node) do
    case :persistent_term.get({__MODULE__, node}, :error) do
      :error ->
        modules = Enum.map(:erpc.call(node, :code, :all_loaded, []), &elem(&1, 0))
        :persistent_term.put({__MODULE__, node}, modules)
        modules

      [_ | _] = modules ->
        modules
    end
  end

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
    ctx = %{
      fragment: hint,
      intellisense_context: intellisense_context,
      matcher: @prefix_matcher,
      type: :completion,
      node: node
    }

    case context = cursor_context(hint) do
      {:ok, tokens, _} -> context_to_matches(tokens, ctx)
      {:error, _, _} -> []
    end
    []
  end


  defp context_to_matches(tokens, ctx) do
    current_token = List.last(tokens)
    IO.inspect(current_token)
    result = case current_token do
      {:":", _} -> suggest_function(ctx)
      _ -> []
    end

    IO.inspect(result)
    result
  end

  defp suggest_function(ctx, funs \\ nil) do
    module = ctx.fragment
    |> String.slice(0, String.length(ctx.fragment)-1)
    |> String.to_atom()

    IO.inspect(module)

    callables =
    try do
      IEx.Autocomplete.exports(module)
    rescue
      _e in UndefinedFunctionError -> []
    end

    callables
    |> Enum.map(&(
      %{
          kind: :function,
          module: module,
          name: elem(&1, 0),
          arity: elem(&1, 1),
          type: nil,
          display_name: Atom.to_string(elem(&1, 0)),
          from_default: nil,
          documentation: nil,
          signatures: nil,
          specs: nil,
          meta: nil
        }
     ))
  end


  def cursor_context(hint) do
    :erl_scan.string(String.to_charlist(hint))
  end
end

defmodule Livebook.Intellisense.Erlang.IdentifierMatcher do
  alias Livebook.Intellisense
  alias Livebook.Intellisense.Elixir.IdentifierMatcher, as: ExMatcher

  @prefix_matcher &String.starts_with?/2

  @spec completion_identifiers(String.t(), Intellisense.context(), node()) ::
          list(ExMatcher.identifier_item())
  def completion_identifiers(hint, intellisense_context, node) do
    scanned = hint |> String.to_charlist() |> :erl_scan.string()
    case scanned do
      {:error, _, _} -> []
      {:ok, tokens, _} -> tokens_to_matches(tokens, hint, intellisense_context, node)
    end
  end

  defp tokens_to_matches(tokens, hint, intellisense_context, node) do
    context = tokens |> Enum.reverse()

    ctx = %{
      fragment: hint,
      intellisense_context: intellisense_context,
      matcher: @prefix_matcher,
      type: :completion,
      node: node
    }

    context_to_matches(context, ctx)
  end

  defp context_to_matches(context, ctx) do
    case context do
      # function from a module
      [{:":", _}, {:atom, _, mod} | _] -> ExMatcher.match_module_function(mod, "", ctx)
      [{:atom, _, hint}, {:":", _}, {:atom, _, mod} | _] ->
        ExMatcher.match_module_function(mod, Atom.to_string(hint), ctx)

      # context not supported
      _ -> []
    end
  end
end

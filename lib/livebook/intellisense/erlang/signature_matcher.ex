defmodule Livebook.Intellisense.Erlang.SignatureMatcher do
  alias Livebook.Intellisense

  @type signature_info :: {name :: atom(), Docs.signature(), Docs.documentation(), Docs.spec()}


  @spec get_matching_signatures(String.t(), Livebook.Intellisense.context(), node()) ::
          {:ok, list(signature_info()), active_argument :: non_neg_integer()} | :error
  def get_matching_signatures(hint, _intellisense_context, node) do
    case call_target_and_argument(hint) do
      {:ok, {:remote, mod, name}, active_argument} ->
        signature_infos =
          Intellisense.Elixir.SignatureMatcher.signature_infos_for_members(
            mod,
            [{name, :any}],
            active_argument,
            node
          )

        {:ok, signature_infos, active_argument}

      {:ok, {:local, name}, active_argument} ->
        signature_infos =
          Intellisense.Elixir.SignatureMatcher.signature_infos_for_members(
            :erlang,
            [{name, :any}],
            active_argument,
            node
          )

        {:ok, signature_infos, active_argument}

      _ ->
        :error
    end
  end

  defp call_target_and_argument(hint) do
    with {:ok, ast} <- parse_last_call(hint) do
      [call_head | _] = ast
      case call_head do
        {:call, _,  {:remote, _, {:atom, _, mod}, {:atom, _, name}}, args} ->
          {:ok, {:remote, mod, name}, length(args) - 1}
        {:call, _, {:atom, _, name}, args} ->
          {:ok, {:local, name}, length(args) - 1}
        _ -> :error
      end
    else
      _ -> :error
    end
  end

  defp parse_last_call(hint) do
    case :erl_scan.string(String.to_charlist(hint)) do
      {:ok, tokens, _} ->
        tokens
        |> filter_last_call
        |> Enum.concat([{:atom, 1, :__context__}, {:")", 1}, {:dot, 1}])
        |> :erl_parse.parse_exprs
      error ->
        error
    end
  end

  defp filter_last_call(tokens), do:
    tokens
    |> Enum.reverse
    |> filter_last_call(:strip_end)

  defp filter_last_call([], _) do
    []
  end
  defp filter_last_call(tokens, :strip_end) do
    case tokens do
      [{:"(", 1} | ttail] -> filter_last_call(ttail, :function_name) ++ [{:"(", 1}]
      [{:",", 1} | ttail] -> filter_last_call(ttail, :args) ++ [{:",", 1}]
      [{:")", 1} | ttail] -> filter_last_call(ttail, {:strip_brackets, 1})
      [_ | ttail] -> filter_last_call(ttail, :strip_end)
    end
  end
  defp filter_last_call(tokens, {:strip_brackets, nesting_level}) do
    case tokens do
      [{:"(", 1} | ttail] when nesting_level == 1 -> filter_last_call(ttail, :strip_end)
      [{:"(", 1} | ttail] -> filter_last_call(ttail, {:strip_brackets, nesting_level - 1})
      [{:")", 1} | ttail] -> filter_last_call(ttail, {:strip_brackets, nesting_level + 1})
      [_ | ttail] -> filter_last_call(ttail, {:strip_brackets, nesting_level})
    end
  end
  defp filter_last_call(tokens, :args) do
    case tokens do
      [{:"(", 1} | ttail] -> filter_last_call(ttail, :function_name) ++ [{:"(", 1}]
      [{:")", 1} | ttail] -> filter_last_call(ttail, :args_bracket) ++ [{:")", 1}]
      [tok | ttail] -> filter_last_call(ttail, :args) ++ [tok]
    end
  end
  defp filter_last_call(tokens, :args_bracket) do
    case tokens do
      [{:"(", 1} | ttail] -> filter_last_call(ttail, :args) ++ [{:"(", 1}]
      [tok | ttail] -> filter_last_call(ttail, :args_bracket) ++ [tok]
    end
  end
  defp filter_last_call(tokens, :function_name) do
    case tokens do
      [{:atom, 1, fun}, {:":", 1}, {:atom, 1, mod} | _] -> [{:atom, 1, mod}, {:":", 1}, {:atom, 1, fun}]
      [{:atom, 1, fun} | _] -> [{:atom, 1, fun}]
      _ -> []
    end
  end
end

defmodule Commands.ChangeState do
  @behaviour Gen.GenBehaviour

  defstruct [:value, :args]

  def writeEx(%Gen.GenState{} = state, %Commands.ChangeState{} = cmd) do
    argNames = case Map.get(state.states_args, cmd.value) do
      nil -> []
      x -> Map.keys(x)
    end
    argVals = Enum.map(cmd.args, fn x -> Gen.GenEx.stringifyASTwithLookup(x) end)
    args = [":state => :#{cmd.value}" | Enum.zip(argNames, argVals) |> Enum.map(fn {x, y} -> ":#{x} => #{y}" end)]
    "state = updateState(state, %{#{Enum.join(args, ", ")}})"
  end

  def writeMcrl2(%Gen.GenState{} = state, %Commands.ChangeState{} = cmd) do
    args = Keyword.keys(state.mcrl2_static_state) ++ cmd.args
    |> Enum.map(&Gen.GenMcrl2.stringifyAST/1)
    |> Enum.join(", ")
    Gen.Helpers.writeLn(state, "#{state.module_name}_#{cmd.value}(#{args})")
  end
end

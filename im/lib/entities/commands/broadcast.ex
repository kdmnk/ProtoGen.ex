defmodule Commands.Broadcast do
  @behaviour Gen.GenBehaviour

  defstruct [:to, :message]

  def writeEx(%Gen.GenState{} = state, %Commands.Broadcast{} = cmd) do
    message = Gen.GenEx.stringifyASTwithLookup(cmd.message)
    message = if(state.struct_message_type, do: "Message.new#{message}", else: message)
    """
    #{Gen.GenEx.writeLog(state, "broadcasting \#{inspect(#{message})} to #{Gen.GenEx.stringifyASTwithLookup(cmd.to)}")}
    #{Gen.GenEx.stringifyASTwithLookup(cmd.to)}
    |> Enum.filter(fn c -> c != {__MODULE__, Node.self()} end)
    |> Enum.map(fn c -> GenServer.cast(c, {{__MODULE__, Node.self()}, #{message}}) end)
    """
  end

  def writeMcrl2(%Gen.GenState{} = state, %Commands.Broadcast{} = cmd) do
    Gen.Helpers.writeLn(state, "broadcastMessages(pid, #{Gen.GenMcrl2.stringifyAST(cmd.to)}, MakeMessage(#{Gen.GenMcrl2.stringifyAST(cmd.message)}))")
  end

end

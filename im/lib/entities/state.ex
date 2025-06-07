defmodule Entities.State do
  @behaviour Gen.GenBehaviour

  defstruct [:value, :args, :body, :timeout]

  def writeEx(%Gen.GenState{} = state, %__MODULE__{} = cmd) do
    state = %Gen.GenState{state | current_state: cmd.value}
    body = Gen.GenEx.writeCmds(state, cmd.body)

    timeout = if cmd.timeout != nil && cmd.timeout != [] do
      Gen.GenEx.writeCmds(state, cmd.timeout)
    else
      ""
    end
    """
    #{body}
    #{timeout}
    """
  end

  def writeMcrl2(%Gen.GenState{} = state, %__MODULE__{} = cmd) do
    state = %Gen.GenState{state | current_state: cmd.value}
    args = case cmd.args do
      nil -> []
      x -> Keyword.new(x)
    end
    Gen.Helpers.writeLn(state, "#{state.module_name}_#{cmd.value}(#{Gen.Helpers.getState(Keyword.merge(state.mcrl2_static_state, args))}) = ")

    recursive_args = Keyword.keys(state.mcrl2_static_state) ++ Keyword.keys(args)
    |> Enum.join(", ")

    ## canReceiveAMessage
    Gen.Helpers.writeLn(Gen.GenState.indent(state), "(sum msg : MessageData . sum pid2 : Pid . canReceiveAMessage (pid , pid2 , msg) .")
    Gen.Helpers.writeLn(Gen.GenState.indent(state, 2), "#{state.module_name}_#{cmd.value}_ReceiveMessages(#{recursive_args}))")

    ## timeout
    if cmd.timeout != nil && cmd.timeout != [] do
      Gen.Helpers.writeLn(Gen.GenState.indent(state), "+ timeout(pid) . ")
      Gen.GenMcrl2.writeCmds(Gen.GenState.indent(state, 2), cmd.timeout, "+")
    end

    ## crash
    Gen.Helpers.writeLn(Gen.GenState.indent(state), "+ (ALLOW_CRASH) -> crash(pid) . #{state.module_name}_#{cmd.value}_Crashed(#{recursive_args});\n")


    ## receive message state
    Gen.Helpers.writeLn(state, "#{state.module_name}_#{cmd.value}_ReceiveMessages(#{Gen.Helpers.getState(Keyword.merge(state.mcrl2_static_state, args))}) = ")
    Gen.GenMcrl2.writeCmds(Gen.GenState.indent(state), cmd.body, "+")
    Gen.Helpers.writeLn(state, ";\n")

    ## crash state
    Gen.Helpers.writeLn(state, "#{state.module_name}_#{cmd.value}_Crashed(#{Gen.Helpers.getState(Keyword.merge(state.mcrl2_static_state, args))}) = ")
    Gen.Helpers.writeLn(Gen.GenState.indent(state), "(sum server : Pid . sum m : MessageData . receiveMessage(pid, server, m)) . #{state.module_name}_#{cmd.value}_Crashed(#{recursive_args})")
    Gen.Helpers.writeLn(Gen.GenState.indent(state), "+ resume(pid) . #{state.module_name}_#{cmd.value}(#{recursive_args})")


  end
end

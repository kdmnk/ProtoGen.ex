defmodule Gen.GenMcrl2 do
  alias Entities.Process

  def main(protocol) do
    name = String.split("#{protocol}", ".") |> List.last |> String.downcase
    folder = "./generated/#{name}/mcrl2"
    :ok = File.mkdir_p(folder)

    conf = Conf.getConf(protocol)
    run(folder, conf)
  end

  def run(folder, %{
      :messageType => messageType,
      :lossyNetwork => lossyNetwork,
      :allowCrash => allowCrash,
      :successLabel => successLabel,
      :failedLabel => failedLabel,
      :customLabels => customLabels,
      :fifoNetwork => fifoNetwork,
      :processes => processes}) do
    state = Gen.GenState.new("#{folder}/specs.mcrl2")

    Gen.Helpers.write(state, getDeclarationsString(messageType, lossyNetwork, allowCrash, processes, customLabels, fifoNetwork))

    for %Process{} = p <- processes do
      mcrl2_static_state = Keyword.merge([pid: "Pid"], p.state)
      state = %Gen.GenState{state | module_name: p.identifier, mcrl2_static_state: mcrl2_static_state, indentation: state.indentation+1}
      Process.writeMcrl2(p, state)
    end

    Gen.Helpers.write(state, getNetworkString(fifoNetwork))
    Gen.Helpers.write(state, getInitString(processes, successLabel, failedLabel, customLabels, fifoNetwork))

    File.close(state.file)
  end


  def writeCmds(state, cmds, separator \\ "."), do:
    Gen.Helpers.join(
      fn (cmd) -> Commands.Command.writeMcrl2(state, cmd) end,
      cmds,
      fn -> Gen.Helpers.writeLn(state, separator) end
    )

  defp getDeclarationsString(messageType, lossyNetwork, allowCrash, processes, customLabels, fifoNetwork) do
    randomPids = Enum.zip(1..100, processes)
    |> Enum.map(fn {n, p} ->
      case p.quantity do
        x when x > 1 and x != nil ->
          pids = Enum.join(Enum.map(1..x, fn y -> "#{n}00#{y}" end), ", ")
          "map #{p.identifier}_PID : List(Pid);\neqn #{p.identifier}_PID = [#{pids}];\n"
        _ -> "map #{p.identifier}_PID : Pid;\neqn #{p.identifier}_PID = #{n}000;"
      end
    end)
    |> Enum.join("")

    labelsDeclaration = if customLabels do
      Enum.map(customLabels, fn {k, v} ->
        if(length(v) > 0) do
          "#{k} : #{Enum.join(Gen.Helpers.typeToMcrl2(v), " # ")};"
        else
          "#{k};"
        end
      end)
      |> Enum.join(" ")
    else
      ""
    end

    messageData = case messageType do
      keyword when is_list(keyword) ->
        Keyword.keys(keyword) |> Keyword.new(fn v -> {v, Gen.Helpers.typeToMcrl2(Keyword.get(keyword, v))} end)
      _ -> Gen.Helpers.typeToMcrl2(messageType)
    end

    messageDataStr = case messageData do
      map when is_list(map) -> "struct MessageData(#{Enum.map(map, fn {k, v} -> "#{k}: #{v}" end) |> Enum.join(", ")})"
      _ -> messageData
    end

    makeMessageStr = case messageData do
      map when is_list(map) ->
        """
        map MakeMessage: #{Keyword.values(map) |> Enum.join(" # ")} -> MessageData;
        var #{Keyword.keys(map) |> Enum.map(fn k -> "_#{k}: #{Keyword.get(map, k)};" end) |> Enum.join(" ")}
        eqn MakeMessage(#{Keyword.keys(map) |> Enum.map(fn k -> "_#{k}" end) |> Enum.join(", ")}) = MessageData(#{Keyword.keys(map) |> Enum.map(fn k -> "_#{k}" end) |> Enum.join(", ")});
        """
      _ ->
        """
        map MakeMessage: #{messageData} -> MessageData;
        var msg: #{messageData};
        eqn MakeMessage(msg) = msg;
        """
    end

    """
    sort Pid = Nat;
    sort MessageData = #{messageDataStr};
    sort Message = struct Message(senderID: Pid, receiverID: Pid, message: MessageData);

    map LOSSY_NETWORK : Bool;
    eqn LOSSY_NETWORK = #{if(is_nil(lossyNetwork), do: "false", else: lossyNetwork)};

    map ALLOW_CRASH : Bool;
    eqn ALLOW_CRASH = #{if(is_nil(allowCrash), do: "false", else: allowCrash)};

    map NETWORK_LIMIT : Nat;
    eqn NETWORK_LIMIT = 20;

    #{makeMessageStr}
    #{randomPids}

    #{getBroadcastedMessagesFn(fifoNetwork)}

    act
      sendMessage, receiveMessage, networkReceiveMessage, networkSendMessage, outgoingMessage, incomingMessage, canReceiveAMessage, exposeNextMessage, canReceiveNextMessage: Pid # Pid # MessageData;
      broadcastMessages, networkBroadcastMessages, broadcast: Pid # List(Pid) # MessageData;
      lose, done, fail, emptyNetwork, protocolDone;
      resume, crash, timeout: Pid;
      #{labelsDeclaration}
    proc
    """
  end

  defp getBroadcastedMessagesFn(true), do: """
  map SplitBroadcastedMessages: Pid # List(Pid) # MessageData -> List(Message);
  var v_sender: Pid;
    v_receivers: List(Pid);
      v_message: MessageData;
  eqn SplitBroadcastedMessages(v_sender, v_receivers, v_message) =
      SplitBroadcastedMessagesHelper(v_sender, v_receivers, v_message, []);
  map SplitBroadcastedMessagesHelper: Pid # List(Pid) # MessageData # List(Message) -> List(Message);
  var v_sender: Pid;
      v_receivers: List(Pid);
      v_message: MessageData;
      v_msgs: List(Message);
  eqn ((# v_receivers) == 0) 
          -> SplitBroadcastedMessagesHelper(v_sender, v_receivers, v_message, v_msgs) 
          = v_msgs;
      ((# v_receivers) > 0 && head(v_receivers) == v_sender)  
          -> SplitBroadcastedMessagesHelper(v_sender, v_receivers, v_message, v_msgs) 
          = SplitBroadcastedMessagesHelper(v_sender, tail(v_receivers), v_message, v_msgs);
      ((# v_receivers) > 0 && head(v_receivers) != v_sender)  
          -> SplitBroadcastedMessagesHelper(v_sender, v_receivers, v_message, v_msgs) 
          = SplitBroadcastedMessagesHelper(v_sender, tail(v_receivers), v_message, v_msgs
                <| Message(v_sender, head(v_receivers), v_message));
  """

  defp getBroadcastedMessagesFn(_), do: """
  map SplitBroadcastedMessages: Pid # List(Pid) # MessageData -> FSet(Message);
  var v_sender: Pid;
      v_receivers: List(Pid);
      v_message: MessageData;
  eqn SplitBroadcastedMessages(v_sender, v_receivers, v_message) =
      SplitBroadcastedMessagesHelper(v_sender, v_receivers, v_message, {});
  map SplitBroadcastedMessagesHelper: Pid # List(Pid) # MessageData # FSet(Message) -> FSet(Message);
  var v_sender: Pid;
      v_receivers: List(Pid);
      v_message: MessageData;
      v_msgs: FSet(Message);
  eqn ((# v_receivers) == 0) -> SplitBroadcastedMessagesHelper(v_sender, v_receivers, v_message, v_msgs) = v_msgs;
      ((# v_receivers) > 0)  -> SplitBroadcastedMessagesHelper(v_sender, v_receivers, v_message, v_msgs) =
                       SplitBroadcastedMessagesHelper(v_sender, tail(v_receivers), v_message, v_msgs
                       + {Message(v_sender, head(v_receivers), v_message)} );
  """

  ## list 
  defp getNetworkString(true), do: """
    Network(msgs: List(Message)) =
    (sum sender : Pid, msg: MessageData . ((# msgs) < NETWORK_LIMIT) -> (
      (sum receiver : Pid .
        networkReceiveMessage(sender, receiver, msg) .
        Network(msgs = msgs <| Message(sender, receiver, msg))
      )
      +
      (sum receivers: List(Pid) .
        networkBroadcastMessages(sender, receivers, msg) .
        Network(msgs = msgs ++ SplitBroadcastedMessages(sender, receivers, msg)))
     ))
     +
      ((# msgs) > 0) -> (
        (exposeNextMessage(receiverID(head(msgs)), senderID(head(msgs)), message(head(msgs))) .
            networkSendMessage(receiverID(head(msgs)), senderID(head(msgs)), message(head(msgs))))
        + ((LOSSY_NETWORK) -> lose)
      ) . Network(msgs = tail(msgs))
     + ((# msgs) == 0) -> (emptyNetwork . Network());
  """

  ## set
  defp getNetworkString(_), do: """
    Network(msgs: FSet(Message)) =
      (sum sender : Pid, msg: MessageData . ((# msgs) < NETWORK_LIMIT) -> (
        (sum receiver : Pid .
          networkReceiveMessage(sender, receiver, msg) .
          Network(msgs = msgs + {Message(sender, receiver, msg)})
        )
        +
        (sum receivers: List(Pid) .
          networkBroadcastMessages(sender, receivers, msg) .
          Network(msgs = msgs + SplitBroadcastedMessages(sender, receivers, msg)))
       ))
       +
       (sum msg: Message . (msg in msgs) ->
         (
            (exposeNextMessage (receiverID(msg), senderID(msg), message(msg)) .
            networkSendMessage(receiverID(msg), senderID(msg), message(msg)))
           + ((LOSSY_NETWORK) -> lose)
         ) . Network(msgs = msgs - {msg}))
       + ((# msgs) == 0) -> (emptyNetwork . Network());
    """

  defp getInitString(processes, successLabel, failedLabel, customLabels, fifoNetwork) do
    pr = processes
      |> Enum.map(fn p ->
        case p.quantity do
          x when x > 1 and x != nil ->
            Enum.map(0..(x-1), fn q ->
              "#{p.identifier}(" <>
              (["#{p.identifier}_PID . #{q}" | Enum.map(Keyword.values(p.state), fn
                {:pid, v} -> "#{v}_PID"
                {:list, {:pid, v}} -> "#{v}_PID"
                _ -> "***"
               end)]
              |> Enum.join(", "))
              <> ")"
            end)
            |> Enum.join(" || ")
          _ -> "#{p.identifier}(" <>
              (["#{p.identifier}_PID" | Enum.map(Keyword.values(p.state), fn
                {:pid, v} -> "#{v}_PID"
                {:list, {:pid, v}} -> "#{v}_PID"
                _ -> "***"
               end)]
              |> Enum.join(", "))
              <> ")"
        end

      end)
      |> Enum.join(" || ")

    actionLabels = ["outgoingMessage", "incomingMessage","broadcast", "lose", "done", "fail", "timeout", "resume", "crash", "canReceiveNextMessage"] ++ if(customLabels, do: Map.keys(customLabels), else: [])

    """
    init
      allow({#{Enum.join(actionLabels, ", ")}},
      comm({
        sendMessage|networkReceiveMessage -> outgoingMessage
        ,canReceiveAMessage|exposeNextMessage -> canReceiveNextMessage
        ,networkSendMessage|receiveMessage -> incomingMessage
        ,broadcastMessages|networkBroadcastMessages -> broadcast
        #{if(successLabel, do: ",#{Enum.join(successLabel, "|")} -> done", else: "")}
        #{if(failedLabel, do: ",#{Enum.join(failedLabel, "|")} -> fail", else: "")}
      },
        #{pr} || Network(#{if(fifoNetwork, do: "[]", else: "{}")})
      )
    );
    """
  end

  def stringifyAST(ast) do
    case ast do
      {op, _pos, [left, right]} when op in [:==, :!=, :>, :>=, :<=, :<, :-, :*, :+, :in, :/] -> "#{stringifyAST(left)} #{op} #{stringifyAST(right)}"
      {:|, _pos, [left, right]} -> "#{stringifyAST(left)} |> #{stringifyAST(right)}"
      {:or, _pos, [left, right]} -> "(#{stringifyAST(left)} || #{stringifyAST(right)})"
      {:and, _pos, [left, right]} -> "(#{stringifyAST(left)} && #{stringifyAST(right)})"
      {:!, _pos, arg} -> "!#{stringifyAST(arg)}"
      {:length, _pos, arg} -> "# #{stringifyAST(arg)}"
      {:ceil, _pos, arg} -> "ceil(#{stringifyAST(arg)})"
      {:floor, _pos, arg} -> "floor(#{stringifyAST(arg)})"
      {:self, _pos, _arg} -> "pid"
      self when is_pid(self) -> "pid"
      {:index, _pos, [arg1, arg2]} -> "#{stringifyAST(arg1)} . #{stringifyAST(arg2)}"
      {:{}, _pos, arg} -> "{#{stringifyAST(arg)}}"
      [a | b] when b != [] -> "(#{stringifyAST(a)}, #{stringifyAST(b)})"
      [a] -> "(#{stringifyAST(a)})"
      {var, _pos, nil} -> var
      {atom, _pos, args} when is_atom(atom) -> "#{atom}(#{stringifyAST(args)})"
      tuple when is_tuple(tuple) -> "#{Enum.map(Tuple.to_list(tuple), fn v -> stringifyAST(v) end) |> Enum.join(", ")}"
      boolean when boolean in ["true", :true, true, "false", :false, false] -> boolean
      var when is_atom(var) -> var
      var when is_binary(var) -> var
      int when is_integer(int) -> int
      [] -> "[]"
    end
  end

end

defmodule Protocols.Addition do
  use Dsl.Im,
    extensions: [Dsl.Root]

  messageType :Nat
  successLabel [:protocolDone, :emptyNetwork]

  process Client, %{:server => {:pid, Server}} do
    init do
      send! :server, 1
      state! :wait_for_answer, []
    end
    state :wait_for_answer, %{} do
      rcv! {:n, :server}, :n == 2 do
        label! :protocolDone, []
      end
    end
  end

  process Server, %{} do
    init do
      state! :wait_for_number, []
    end
    state :wait_for_number, %{} do
      rcv! {:n, :some_client}, true do
        send! :some_client, :n+1
      end
    end
  end
end

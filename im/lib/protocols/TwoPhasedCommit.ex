defmodule Protocols.TwoPhasedCommit do
  use Dsl.Im,
    extensions: [Dsl.Root]

  messageType :Nat
  lossyNetwork false
  successLabel [:protocolDone, :emptyNetwork]

  process User, %{}, 3 do
    init do
      state! :idle, []
    end
    state :idle do
      rcv! {:m, :server}, :m == 0 do
        choice! :answer, [1, 2] do
          send! :server, :answer
        end
        state! :wait_for_server, []
      end
    end
    state :wait_for_server do
      rcv! {:m, :server}, :m == 3 do
        send! :server, 5
      end
      rcv! {:m, :server}, :m == 4 do
        send! :server, 5
      end
    end
  end

  process Mach, %{:users => {:list, {:pid, User}}}, 1 do
    init do
      broadcast! :users, 0
      state! :receive_messages, [[], length(:users)]
    end
    state :receive_messages, %{:msgs => {:list, :Nat}, :remaining => :Int} do
      rcv! {:m, :some_user}, (:m == 1 or :m == 2) and :remaining > 1 do
        state! :receive_messages, [[:m | :msgs], :remaining-1]
      end
      rcv! {:m, :some_user}, (:m == 1 or :m == 2) and :remaining == 1 do
        if! 1 in [:m | :msgs] do
          then! do
            broadcast! :users, 3
            state! :receive_acks, [length(:users)]
          end
          else! do
            broadcast! :users, 4
            state! :receive_acks, [length(:users)]
          end
        end
      end
    end
    state :receive_acks, %{:remaining => :Int} do
      rcv! {:m, :some_user}, :m == 5 and :remaining > 1 do
        state! :receive_acks, [:remaining -1]
      end
      rcv! {:m, :some_user}, :m == 5 and :remaining == 1 do
        label! :protocolDone, []
      end
    end
  end
end

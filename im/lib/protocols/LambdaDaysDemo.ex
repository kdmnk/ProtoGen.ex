defmodule Protocols.LambdaDaysDemo do
  use Dsl.Im,
    extensions: [Dsl.Root]

  messageType :Nat
  lossyNetwork false
  allowCrash false
  fifoNetwork true
  successLabel [:protocolDone, :protocolDone, :protocolDone]
  customLabels %{:electedAsLeader => [], :failedToElect => []}


  # Message codes:
  # 11 vote request
  # 12 new leader
  # 1 approve
  # 0 decline

  process DemoNode, %{:all_nodes => {:list, {:pid, DemoNode}}}, 3 do
    
    init do
      state! :idle, [false]
    end

    state :idle, %{:voted => :Bool} do
      # receive vote request
      rcv! {:msg, :from}, :msg == 11 do
        if! :voted == false do
          then! do
            send! :from, 1 # approve
            state! :idle, [true]
          end
          else! do
            send! :from, 0 # decline
            state! :idle, [:voted]
          end
        end
      end

      # receive new leader
      rcv! {:msg, :candidate}, :msg == 12 do
        label! :protocolDone, []
      end
      
      timeout do
        if! :voted == false do
          then! do
            broadcast! :all_nodes, 11
            state! :candidate, [
              ceil(length(:all_nodes) / 2) -1,
              length(:all_nodes) - 1
            ]
          end
          else! do
             state! :idle, [:voted]
          end
        end
      end
    end

    state :candidate, %{:approves_needed => :Int, :remaining_messages => :Int,} do
    
      # receive vote
      rcv! {:msg, :some_user}, (:msg == 1 or :msg == 0) and :remaining_messages > 1 do
          state! :candidate, [:approves_needed - :msg, :remaining_messages - 1]
      end

      # receive last vote
      rcv! {:msg, :some_user}, (:msg == 1 or :msg == 0) and :remaining_messages == 1 do
        if! (:approves_needed - :msg) <= 0 do
          then! do
            # elected
            broadcast! :all_nodes, 12
            label! :electedAsLeader, []
            label! :protocolDone, []
          end
          else! do
            label! :failedToElect, []
            state! :candidate, [99, :remaining_messages - 1] 
          end
        end
      end
      
      # receive vote request
      rcv! {:msg, :candidate}, :msg == 11 do
          send! :candidate, 0 # decline
          state! :candidate, [:approves_needed, :remaining_messages]
      end

      # # receive new leader
      rcv! {:msg, :candidate}, :msg == 12 do
        label! :protocolDone, []
      end
    end
  end
end

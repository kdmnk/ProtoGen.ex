defmodule Protocols.RaftBroken do
  use Dsl.Im,
    extensions: [Dsl.Root]

  messageType :Nat
  lossyNetwork false
  allowCrash false
  successLabel [:protocolDone, :protocolDone, :protocolDone]
  fifoNetwork true
  customLabels %{:exposeLeader => [:Nat], :failedToElect => []}


  ## 4 init voting
  ## 1 approve
  ## 0 decline

  ## 5 new leader

  process Node, %{:all_nodes => {:list, {:pid, Node}}}, 3 do
    
    init do
      state! :idle, [false]
    end

    state :idle, %{:voted => :Bool} do
      # receive vote request
      rcv! {:m, :candidate}, :m == 4 do
        if! :voted == false do
          then! do
            send! :candidate, 1 # approve
            state! :idle, [true]
          end
          else! do
            send! :candidate, 0 # decline
            state! :idle, [true]
          end
        end
      end

      # receive new leader
      rcv! {:m, :candidate}, :m == 5 do
        label! :protocolDone, []
      end
      
      timeout do
        if! :voted == false do
          then! do
            broadcast! :all_nodes, 4
            state! :candidate, [
              length(:all_nodes) - 1, 
              ceil(length(:all_nodes) / 2) -1
            ]
          end
          else! do
             state! :idle, [:voted]
          end
        end
      end
    end

    state :candidate, %{:remaining_messages => :Int, :approves_needed => :Int} do
    
      # receive vote
      rcv! {:m, :some_user}, (:m == 1 or :m == 0) and :remaining_messages > 1 do
          state! :candidate, [:remaining_messages - 1, :approves_needed - :m]
      end

      # receive last vote
      rcv! {:m, :some_user}, (:m == 1 or :m == 0) and :remaining_messages == 1 do
        if! (:approves_needed - :m) <= 0 do
          then! do
            # elected
            broadcast! :all_nodes, 5
            label! :protocolDone, []
          end
          else! do
            label! :failedToElect, []
            state! :candidate, [:remaining_messages - 1, 99] 
          end
        end
      end
      
      # receive vote request
      rcv! {:m, :candidate}, :m == 4 do
          send! :candidate, 0 # decline
          state! :candidate, [:remaining_messages, :approves_needed]
      end

      # receive new leader
      rcv! {:m, :candidate}, :m == 5 do
        label! :protocolDone, []
      end  
    end
  end
    
  #   state :leader, %{} do
  #     # ignore remaining votes
  #     rcv! {:m, :some_user}, (:m == 1 or :m == 2) do
  #       state! :leader, []
  #     end

  #     # receive vote request
  #     rcv! {:m, :candidate}, :m == 0 do
  #       send! :candidate, 2# decline
  #       state! :leader, []
  #     end

  #     timeout do
  #       label! :protocolDone, []
  #     end
  #   end
  # end
end

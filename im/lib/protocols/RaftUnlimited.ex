defmodule Protocols.RaftUnlimited do
  use Dsl.Im,
    extensions: [Dsl.Root]

  messageType [t: :Nat, data: :Nat]
  lossyNetwork false
  allowCrash true
  successLabel [:protocolDone, :protocolDone, :protocolDone, :protocolDone, :protocolDone]
  fifoNetwork true
  customLabels %{:exposeLeader => [:Nat, :Nat]}

  process Candidate, %{:others => {:list, {:pid, Candidate}}}, 5 do
    init do
      state! :idle, [0]
    end
    state :candidate_wait_ack, %{:term => :Nat, :remaining_good => :Int, :allowed_bad => :Int} do
      # ignore messages with older terms
      rcv! {:m, :some_user}, t(:m) < :term do
        state! :candidate_wait_ack, [:term, :remaining_good, :allowed_bad]
      end
    # receive approve vote
      rcv! {:m, :some_user}, data(:m) == 1 and t(:m) == :term do
        if! :remaining_good > 1 do
          then! do
            state! :candidate_wait_ack, [:term, :remaining_good - 1, :allowed_bad]
          end
          else! do
            broadcast! :others, {:term, 5}
            label! :exposeLeader, [self(), :term]
            state! :leader, [:term]
          end
        end
      end
      # receive decline vote
      rcv! {:m, :some_user}, data(:m) == 2 and t(:m) == :term do
        if! :allowed_bad > 0 do
          then! do
            state! :candidate_wait_ack, [:term, :remaining_good, :allowed_bad - 1]
          end
          else! do
            state! :idle, [:term]
          end
        end
      end
      # receive vote request in same term
      rcv! {:m, :candidate}, data(:m) == 0 and t(:m) == :term do
        if! :candidate == self() do
          then! do
            send! :candidate, {t(:m), 1}
            state! :candidate_wait_ack, [:term, :remaining_good, :allowed_bad]
          end
          else! do
            send! :candidate, {:term, 2}
            state! :candidate_wait_ack, [:term, :remaining_good, :allowed_bad]
          end
        end
      end
      # receive vote request in higher term
      rcv! {:m, :candidate}, data(:m) == 0 and t(:m) > :term do
        if! :candidate == self() do
          then! do
            send! :candidate, {t(:m), 1}
            state! :candidate_wait_ack, [:term, :remaining_good, :allowed_bad]
          end
          else! do
            send! :candidate, {t(:m), 1}
            state! :idle, [t(:m)]
          end
        end
      end
      # receive new leader
      rcv! {:m, :candidate}, data(:m) == 5 and t(:m) >= :term do
        label! :protocolDone, []
        state! :idle, [t(:m)]
      end
    end
    state :idle, %{:term => :Nat} do
      # receive vote request (higher term)
      rcv! {:m, :candidate}, data(:m) == 0 and t(:m) > :term do
        send! :candidate, {t(:m), 1} # approve
        state! :idle, [t(:m)]
      end
      # receive vote request (same term)
      rcv! {:m, :candidate}, data(:m) == 0 and t(:m) == :term do
        send! :candidate, {t(:m), 2} # decline
        state! :idle, [:term]
      end
      # ignore messages with lower term
      rcv! {:m, :candidate}, t(:m) < :term do
        state! :idle, [:term]
      end
      # receive new leader
      rcv! {:m, :candidate}, data(:m) == 5 and t(:m) >= :term do
        label! :protocolDone, []
        state! :idle, [t(:m)]
      end
      # ignore remaining votes
      rcv! {:m, :some_user}, (data(:m) == 1 or data(:m) == 2) and t(:m) == :term do
        state! :idle, [:term]
      end
      timeout do
        broadcast! :others, {:term+1, 0}
        state! :candidate_wait_ack, [:term + 1, ceil(length(:others) / 2), floor(length(:others) / 2)]
      end
    end
    state :leader, %{:term => :Nat} do
      # ignore messages with lower term
      rcv! {:m, :candidate}, t(:m) < :term do
        state! :leader, [:term]
      end
      # ignore remaining votes
      rcv! {:m, :some_user}, (data(:m) == 1 or data(:m) == 2) and t(:m) == :term do
        state! :leader, [:term]
      end
      # receive leader
      rcv! {:m, :candidate}, data(:m) == 5 and t(:m) >= :term do
        if! :candidate == self() do
          then! do
            label! :protocolDone, []
            state! :leader, [t(:m)]
          end
          else! do
            state! :idle, [t(:m)]
          end
        end
      end
      # receive vote request (higher term)
      rcv! {:m, :candidate}, data(:m) == 0 and t(:m) > :term do
        send! :candidate, {t(:m), 1} # approve
        state! :idle, [t(:m)]
      end
      # receive vote request (same term)
      rcv! {:m, :candidate}, data(:m) == 0 and t(:m) == :term do
        send! :candidate, {t(:m), 2} # decline
        state! :leader, [:term]
      end
    end
  end
end

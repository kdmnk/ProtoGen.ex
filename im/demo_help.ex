Gen.GenEx.main(Protocols.RaftBroken)
Gen.GenMcrl2.main(Protocols.RaftBroken)

# iex --name mach@127.0.0.1 -S mix
# iex --name user1@127.0.0.1 -S mix
# iex --name user2@127.0.0.1 -S mix

UserApi.start() |> UserApi.wait()

|> UserApi.chooseAnswer(1)

MachApi.start()


Gen.GenMcrl2.main(Protocols.Demo)
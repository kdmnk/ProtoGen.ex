defmodule Main do
  def runUser() do
    UserApi.start()
    |> UserApi.wait()
    |> UserApi.chooseChooseAnswer(true)
  end

  def runMach() do
    MachApi.start()
  end
end

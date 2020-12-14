defmodule Dispatch.RelevancyBooster do
  defmodule UserRelevancy do
    @enforce_keys [:username, :fullname, :boosters, :score]
    defstruct username: nil, fullname: nil, boosters: nil, score: nil
  end

  def map_users(users) do
    Enum.map(users, fn user ->
      %UserRelevancy{
        username: user.username,
        fullname: user.fullname,
        boosters: [],
        score: 1
      }
    end)
  end

  def calculate(user_relevancies, boosters) do
    Enum.reduce(boosters, user_relevancies, fn {booster_module, options}, memo ->
      apply(booster_module, :apply_booster, [memo, options])
    end)
  end
end

defmodule Dispatch.Repositories.ContributorsTest do
  use ExUnit.Case, async: false

  import Mock

  alias Dispatch.Repositories.Contributor
  alias Dispatch.Repositories.Contributors
  alias Dispatch.SelectedUser
  alias Dispatch.Utils.Random
  alias Dispatch.Utils.TimeHelper

  @this_week 1
  @two_week_ago 15
  @two_month_ago 60
  @five_month_ago 150
  @height_month_ago 240

  test "calculate/1 return contributor total commits plus last three months commits" do
    contributor = %{
      "total" => 125,
      "weeks" => [
        %{
          "w" => TimeHelper.unix_beginning_of_week(@height_month_ago),
          "a" => 0,
          "d" => 0,
          "c" => 100
        },
        %{
          "w" => TimeHelper.unix_beginning_of_week(@five_month_ago),
          "a" => 0,
          "d" => 0,
          "c" => 11
        },
        %{
          "w" => TimeHelper.unix_beginning_of_week(@two_month_ago),
          "a" => 0,
          "d" => 0,
          "c" => 2
        },
        %{
          "w" => TimeHelper.unix_beginning_of_week(@two_week_ago),
          "a" => 0,
          "d" => 0,
          "c" => 10
        },
        %{
          "w" => TimeHelper.unix_beginning_of_week(@this_week),
          "a" => 0,
          "d" => 0,
          "c" => 2
        }
      ],
      "author" => %{
        "login" => "happy_potter"
      }
    }

    result = Contributors.calculate_relevancy(contributor)

    assert result == {125, 14, 139}
  end

  @contributors [
    %Contributor{username: "darth_coder", relevancy: 3, recent_commit_count: 1, total_commit_count: 1},
    %Contributor{username: "php_amidala", relevancy: 2, recent_commit_count: 1, total_commit_count: 1},
    %Contributor{username: "brewbacca", relevancy: 3, recent_commit_count: 1, total_commit_count: 1},
    %Contributor{username: "kylo_bytes", relevancy: 1, recent_commit_count: 1, total_commit_count: 1},
    %Contributor{username: "heineken_skywalker", relevancy: 5, recent_commit_count: 1, total_commit_count: 1},
    %Contributor{username: "mail_windu", relevancy: 2, recent_commit_count: 1, total_commit_count: 1},
    %Contributor{username: "java_fett", relevancy: 4, recent_commit_count: 1, total_commit_count: 1}
  ]

  @test_cases [
    %{random_pick: 1, expected: %{username: "darth_coder", recent_commit_count: 1, total_commit_count: 1}},
    %{random_pick: 7, expected: %{username: "brewbacca", recent_commit_count: 1, total_commit_count: 1}},
    %{random_pick: 11, expected: %{username: "heineken_skywalker", recent_commit_count: 1, total_commit_count: 1}},
    %{random_pick: 20, expected: %{username: "java_fett", recent_commit_count: 1, total_commit_count: 1}}
  ]

  for %{random_pick: random_pick, expected: %{username: username, recent_commit_count: recent_commit_count, total_commit_count: total_commit_count}} <- @test_cases do
    test "select/1 return random contributor based on contributors relevancy (random pick value: #{to_string(random_pick)})" do
      with_mock Random, uniform: fn 20 -> unquote(random_pick) end do
        result = Contributors.select(@contributors)

        assert result == [
                 %SelectedUser{
                   username: unquote(username),
                   type: "contributor",
                   metadata: %{
                     recent_commit_count: unquote(recent_commit_count),
                     total_commit_count: unquote(total_commit_count)
                   }
                 }
               ]
      end
    end
  end

  test "nil contributor list" do
    result = Contributors.select(nil)

    assert result == []
  end

  test "empty contributor list" do
    result = Contributors.select([])

    assert result == []
  end
end

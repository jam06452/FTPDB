defmodule Ftpdb.DB do
  require Logger
  def client do
    config = Application.get_env(:ftpdb, :supabase)
    {:ok, client} = Supabase.init_client(config[:url], config[:key])
    client
  end

  def hot do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select(["title", "id"])
      |> Supabase.PostgREST.order("stat_hot_score", desc: true)
      |> Supabase.PostgREST.limit(10)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

      response.body
      |> Map.new(fn item -> {to_string(item["id"]), item["title"]} end)
  end

  def top_this_week do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select(["title", "id", "stat_weekly_rank"])
      |> Supabase.PostgREST.order("stat_weekly_rank", asc: true)
      |> Supabase.PostgREST.limit(10)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

response.body
  |> Enum.map(fn item ->
    %{id: to_string(item["id"]), title: item["title"], rank: item["stat_weekly_rank"]}end)
  end

  def fan_favourites do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select(["title", "id"])
      |> Supabase.PostgREST.order("stat_total_likes", desc: true)
      |> Supabase.PostgREST.limit(10)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Map.new(fn item -> {to_string(item["id"]), item["title"]} end)
  end
end

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
      |> Supabase.PostgREST.select(["title", "id", "banner_url", "stat_total_duration_seconds"])
      |> Supabase.PostgREST.order("stat_hot_score", desc: true)
      |> Supabase.PostgREST.limit(10)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Map.new(fn item ->
      user_id = get_user_id(item["id"])
      [user_info] = get_user_info(user_id)

      {to_string(item["id"]),
       %{
         title: item["title"],
         banner_url: item["banner_url"],
         total_hours: div(item["stat_total_duration_seconds"], 3600)
       }
       |> Map.merge(user_info)}
    end)
  end

  def top_this_week do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select(["title", "id", "stat_weekly_rank", "banner_url"])
      |> Supabase.PostgREST.order("stat_weekly_rank", asc: true)
      |> Supabase.PostgREST.limit(10)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.map(fn item ->
      user_id = get_user_id(item["id"])
      [user_info] = get_user_info(user_id)

      %{
        id: to_string(item["id"]),
        title: item["title"],
        rank: item["stat_weekly_rank"],
        banner_url: item["banner_url"]
      }
      |> Map.merge(user_info)
    end)
  end

  def fan_favourites do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select(["title", "id", "banner_url"])
      |> Supabase.PostgREST.order("stat_total_likes", desc: true)
      |> Supabase.PostgREST.limit(10)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Map.new(fn item ->
      user_id = get_user_id(item["id"])
      [user_info] = get_user_info(user_id)

      {to_string(item["id"]),
       %{title: item["title"], banner_url: item["banner_url"]} |> Map.merge(user_info)}
    end)
  end

  def top_all_time do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select(["title", "id", "stat_all_time_rank", "banner_url"])
      |> Supabase.PostgREST.order("stat_all_time_rank", asc: true)
      |> Supabase.PostgREST.limit(10)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.map(fn item ->
      user_id = get_user_id(item["id"])
      [user_info] = get_user_info(user_id)

      %{
        id: to_string(item["id"]),
        title: item["title"],
        rank: item["stat_all_time_rank"],
        banner_url: item["banner_url"]
      }
      |> Map.merge(user_info)
    end)
  end

  def most_time_spent do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "users")
      |> Supabase.PostgREST.select(["id", "display_name", "avatar_url", "total_time"])
      |> Supabase.PostgREST.order("total_time", desc: true)
      |> Supabase.PostgREST.limit(10)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.map(fn item ->
      total_hours = div(item["total_time"], 3600)

      %{
        id: to_string(item["id"]),
        display_name: item["display_name"],
        avatar_url: item["avatar_url"],
        total_hours: total_hours
      }
    end)
  end

  def get_devlogs(project_id) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "devlogs")
      |> Supabase.PostgREST.select(["body", "duration_seconds", "likes_count", "comments_count"])
      |> Supabase.PostgREST.eq("project_id", project_id)
      |> Supabase.PostgREST.order("created_at", desc: true)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.map(fn item ->
      total_hours = div(item["duration_seconds"], 3600)

      %{
        body: item["body"],
        total_hours: total_hours,
        likes_count: item["likes_count"],
        comments_count: item["comments_count"]
      }
    end)
  end

  def get_user_id(project_id) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "user_projects")
      |> Supabase.PostgREST.select(["user_id"])
      |> Supabase.PostgREST.eq("project_id", project_id)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    [%{"user_id" => user_id}] = response.body
    user_id
  end

  def get_user_info(user_id) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "users")
      |> Supabase.PostgREST.select(["display_name", "avatar_url"])
      |> Supabase.PostgREST.eq("id", user_id)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.map(fn item ->
      %{display_name: item["display_name"], avatar_url: item["avatar_url"]}
    end)
  end

  def get_project_info(project_id) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select([
        "title",
        "description",
        "repo_url",
        "demo_url",
        "ship_status",
        "stat_total_duration_seconds",
        "stat_total_likes",
        "banner_url"
      ])
      |> Supabase.PostgREST.eq("id", project_id)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.map(fn item ->
      total_hours = div(item["stat_total_duration_seconds"], 3600)
      user_id = get_user_id(project_id)
      [user_info] = get_user_info(user_id)

      %{
        title: item["title"],
        description: item["description"],
        repo_url: item["repo_url"],
        demo_url: item["demo_url"],
        ship_status: item["ship_status"],
        total_hours: total_hours,
        total_likes: item["stat_total_likes"],
        banner_url: item["banner_url"]
      }
      |> Map.merge(user_info)
    end)
  end

  def extended_user_info(user_id) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "users")
      |> Supabase.PostgREST.select(["id", "display_name", "avatar_url", "total_time", "slack_id"])
      |> Supabase.PostgREST.eq("id", user_id)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.map(fn item ->
      total_hours = div(item["total_time"], 3600)

      %{
        id: to_string(item["id"]),
        display_name: item["display_name"],
        avatar_url: item["avatar_url"],
        total_hours: total_hours,
        slack_id: item["slack_id"]
      }
    end)
  end

  def search_projects(query) when is_binary(query) do
    cleaned_query = String.trim(query)

    if String.length(cleaned_query) == 0 do
      []
    else
      search_term = "%#{cleaned_query}%"

      {:ok, response} =
        Supabase.PostgREST.from(client(), "projects")
        |> Supabase.PostgREST.select([
          "id",
          "title",
          "banner_url",
          "stat_hot_score",
          "stat_total_likes"
        ])
        |> Supabase.PostgREST.ilike("title", search_term)
        |> Supabase.PostgREST.limit(10)
        |> Map.put(:method, :get)
        |> Supabase.PostgREST.execute()

      response.body
      |> Enum.map(fn item ->
        user_id = get_user_id(item["id"])
        [user_info] = get_user_info(user_id)

        %{
          id: to_string(item["id"]),
          title: item["title"],
          banner_url: item["banner_url"],
          hot_score: item["stat_hot_score"] || 0,
          likes: item["stat_total_likes"] || 0
        }
        |> Map.merge(user_info)
      end)
      |> Enum.sort_by(fn item ->
        # Sort by a weighted combination: 60% hot score, 40% likes
        # Normalize likes to be within reasonable range (divide by 100)
        hot = item.hot_score * 0.6
        likes = item.likes / 100 * 0.4
        -(hot + likes)
      end)
    end
  end
end

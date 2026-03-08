defmodule Ftpdb.DB do
  require Logger

  defp project_duration_fields(duration_seconds) do
    duration_seconds = duration_seconds || 0

    %{
      total_duration_seconds: duration_seconds,
      total_hours: div(duration_seconds, 3600)
    }
  end

  def client do
    config = Application.get_env(:ftpdb, :supabase)
    {:ok, client} = Supabase.init_client(config[:url], config[:key])
    client
  end

  def hot do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select([
        "title",
        "id",
        "banner_url",
        "stat_total_duration_seconds",
        "stat_hot_score",
        "stat_total_likes"
      ])
      |> Supabase.PostgREST.order("stat_hot_score", desc: true)
      |> Supabase.PostgREST.limit(10)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.filter(fn item ->
      user_id = get_user_id(item["id"])
      user_id != nil
    end)
    |> Enum.map(fn item ->
      user_id = get_user_id(item["id"])
      [user_info] = get_user_info(user_id)
      duration = item["stat_total_duration_seconds"] || 0

      project_map =
        %{
          id: to_string(item["id"]),
          title: item["title"],
          banner_url: item["banner_url"],
          display_name: user_info.display_name,
          avatar_url: user_info.avatar_url,
          stat_hot_score: item["stat_hot_score"] || 0,
          devlogs_count: get_devlog_count(item["id"]),
          stat_total_likes: item["stat_total_likes"] || 0
        }
        |> Map.merge(project_duration_fields(duration))

      project_map
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
    |> Enum.filter(fn item ->
      user_id = get_user_id(item["id"])
      user_id != nil
    end)
    |> Enum.map(fn item ->
      user_id = get_user_id(item["id"])
      [user_info] = get_user_info(user_id)

      user_map = %{
        id: to_string(item["id"]),
        title: item["title"],
        rank: item["stat_weekly_rank"],
        banner_url: item["banner_url"]
      }

      Map.merge(user_info, user_map)
    end)
  end

  def fan_favourites do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select([
        "title",
        "id",
        "banner_url",
        "stat_total_likes",
        "stat_total_duration_seconds"
      ])
      |> Supabase.PostgREST.order("stat_total_likes", desc: true)
      |> Supabase.PostgREST.limit(10)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.filter(fn item ->
      user_id = get_user_id(item["id"])
      user_id != nil
    end)
    |> Enum.map(fn item ->
      user_id = get_user_id(item["id"])
      [user_info] = get_user_info(user_id)
      duration = item["stat_total_duration_seconds"] || 0

      %{
        id: to_string(item["id"]),
        title: item["title"],
        banner_url: item["banner_url"],
        display_name: user_info.display_name,
        avatar_url: user_info.avatar_url,
        stat_hot_score: 0,
        stat_total_likes: item["stat_total_likes"] || 0
      }
      |> Map.merge(project_duration_fields(duration))
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
    |> Enum.filter(fn item ->
      user_id = get_user_id(item["id"])
      user_id != nil
    end)
    |> Enum.map(fn item ->
      user_id = get_user_id(item["id"])
      [user_info] = get_user_info(user_id)

      user_map = %{
        id: to_string(item["id"]),
        title: item["title"],
        rank: item["stat_all_time_rank"],
        banner_url: item["banner_url"]
      }

      Map.merge(user_info, user_map)
    end)
  end

  def most_active_projects(limit \\ 10) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select([
        "id",
        "title",
        "banner_url",
        "stat_total_duration_seconds",
        "stat_hot_score",
        "stat_total_likes"
      ])
      |> Supabase.PostgREST.order("stat_total_duration_seconds", desc: true)
      |> Supabase.PostgREST.limit(limit)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.filter(fn item ->
      user_id = get_user_id(item["id"])
      user_id != nil
    end)
    |> Enum.map(fn item ->
      user_id = get_user_id(item["id"])
      [user_info] = get_user_info(user_id)
      duration = item["stat_total_duration_seconds"] || 0

      %{
        id: to_string(item["id"]),
        title: item["title"],
        banner_url: item["banner_url"],
        display_name: user_info.display_name,
        avatar_url: user_info.avatar_url,
        stat_hot_score: item["stat_hot_score"] || 0,
        stat_total_likes: item["stat_total_likes"] || 0
      }
      |> Map.merge(project_duration_fields(duration))
    end)
  end

  def most_time_spent(limit \\ 10) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "users")
      |> Supabase.PostgREST.select(["id", "display_name", "avatar_url", "total_time"])
      |> Supabase.PostgREST.order("total_time", desc: true)
      |> Supabase.PostgREST.limit(limit)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.map(fn item ->
      total_time = item["total_time"] || 0

      %{
        user_id: to_string(item["id"]),
        display_name: item["display_name"],
        avatar_url: item["avatar_url"],
        total_time: total_time,
        total_hours: div(total_time, 3600)
      }
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
      duration = item["stat_total_duration_seconds"] || 0
      user_id = get_user_id(project_id)
      [user_info] = get_user_info(user_id)

      user_info = Map.drop(user_info, [:total_hours])

      project_map =
        %{
          title: item["title"],
          description: item["description"],
          repo_url: item["repo_url"],
          demo_url: item["demo_url"],
          ship_status: item["ship_status"],
          total_likes: item["stat_total_likes"],
          banner_url: item["banner_url"]
        }
        |> Map.merge(project_duration_fields(duration))

      Map.merge(user_info, project_map)
    end)
  end

  def random_projects(limit \\ 10) do
    {:ok, response} =
      client()
      |> Supabase.PostgREST.rpc("get_random_projects", %{limit_count: limit})
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.map(fn item ->
      total_hours = item["stat_total_hours"] || 0
      duration = item["stat_total_duration_seconds"] || total_hours * 3600

      item
      |> Map.drop(["stat_total_duration_seconds"])
      |> Map.put("total_duration_seconds", duration)
      |> Map.put("total_hours", total_hours)
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
      |> Enum.filter(fn item ->
        user_id = get_user_id(item["id"])
        user_id != nil
      end)
      |> Enum.map(fn item ->
        user_id = get_user_id(item["id"])
        [user_info] = get_user_info(user_id)

        project_map = %{
          id: to_string(item["id"]),
          title: item["title"],
          banner_url: item["banner_url"],
          hot_score: item["stat_hot_score"] || 0,
          likes: item["stat_total_likes"] || 0
        }

        Map.merge(user_info, project_map)
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

  def get_user_id(project_id) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "user_projects")
      |> Supabase.PostgREST.select(["user_id"])
      |> Supabase.PostgREST.eq("project_id", project_id)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    case response.body do
      [%{"user_id" => user_id}] -> user_id
      _ -> nil
    end
  end

  def get_user_info(user_id) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "users")
      |> Supabase.PostgREST.select(["id", "display_name", "avatar_url", "total_time", "slack_id"])
      |> Supabase.PostgREST.eq("id", user_id)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.map(fn item ->
      total_time = item["total_time"] || 0
      total_hours = div(total_time, 3600)

      %{
        user_id: to_string(item["id"]),
        display_name: item["display_name"],
        avatar_url: item["avatar_url"],
        total_hours: total_hours,
        slack_id: item["slack_id"]
      }
    end)
  end

  def search_users(query, min_hours \\ 0) when is_binary(query) do
    cleaned_query = String.trim(query)

    if String.length(cleaned_query) == 0 do
      []
    else
      search_term = "%#{cleaned_query}%"

      {:ok, response} =
        Supabase.PostgREST.from(client(), "users")
        |> Supabase.PostgREST.select([
          "id",
          "display_name",
          "avatar_url",
          "total_time"
        ])
        |> Supabase.PostgREST.ilike("display_name", search_term)
        |> Supabase.PostgREST.limit(100)
        |> Map.put(:method, :get)
        |> Supabase.PostgREST.execute()

      min_seconds = min_hours * 3600

      response.body
      |> Enum.map(fn item ->
        total_time = item["total_time"] || 0
        total_hours = div(total_time, 3600)

        %{
          id: to_string(item["id"]),
          display_name: item["display_name"],
          avatar_url: item["avatar_url"],
          total_hours: total_hours,
          total_time: total_time
        }
      end)
      |> Enum.filter(fn user -> user.total_time >= min_seconds end)
      |> Enum.sort_by(fn user -> -user.total_hours end)
      |> Enum.take(10)
    end
  end

  def get_user_projects(user_id) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "user_projects")
      |> Supabase.PostgREST.select(["project_id"])
      |> Supabase.PostgREST.eq("user_id", user_id)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    project_ids =
      response.body
      |> Enum.map(fn item -> item["project_id"] end)

    if Enum.empty?(project_ids) do
      []
    else
      {:ok, response} =
        Supabase.PostgREST.from(client(), "projects")
        |> Supabase.PostgREST.select([
          "id",
          "title",
          "banner_url",
          "stat_total_duration_seconds",
          "stat_total_likes"
        ])
        |> Map.put(:method, :get)
        |> Supabase.PostgREST.execute()

      # Filter locally and sort by hours
      all_projects = response.body || []

      project_ids_set = MapSet.new(project_ids)

      all_projects
      |> Enum.filter(fn item -> MapSet.member?(project_ids_set, item["id"]) end)
      |> Enum.map(fn item ->
        duration = item["stat_total_duration_seconds"] || 0

        %{
          id: to_string(item["id"]),
          title: item["title"],
          banner_url: item["banner_url"],
          total_hours: div(duration, 3600),
          total_likes: item["stat_total_likes"] || 0
        }
      end)
      |> Enum.sort_by(fn p -> -p.total_hours end)
    end
  end

  def get_devlog_count(project_id) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "devlogs")
      |> Supabase.PostgREST.select(["id"])
      |> Supabase.PostgREST.eq("project_id", project_id)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> List.wrap()
    |> length()
  end

  def get_devlogs(project_id) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "devlogs")
      |> Supabase.PostgREST.select([
        "body",
        "duration_seconds",
        "comments_count",
        "created_at",
        "media_urls"
      ])
      |> Supabase.PostgREST.eq("project_id", project_id)
      |> Supabase.PostgREST.order("created_at", desc: true)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    response.body
    |> Enum.map(fn item ->
      duration = item["duration_seconds"] || 0
      total_hours = div(duration, 3600)
      media_urls = item["media_urls"] || []

      %{
        body: item["body"],
        total_hours: total_hours,
        comments_count: item["comments_count"],
        created_at: item["created_at"],
        media_urls: media_urls
      }
    end)
  end

  defp get_max_devlog_id do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "devlogs")
      |> Supabase.PostgREST.select(["id"])
      |> Supabase.PostgREST.order("id", desc: true)
      |> Supabase.PostgREST.limit(1)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    case response.body do
      [%{"id" => max_id}] -> max_id
      _ -> 0
    end
  end

  defp fetch_and_format_devlog(id) do
    result =
      Supabase.PostgREST.from(client(), "devlogs")
      |> Supabase.PostgREST.select([
        "id",
        "body",
        "duration_seconds",
        "comments_count",
        "created_at",
        "media_urls",
        "project_id"
      ])
      |> Supabase.PostgREST.eq("id", id)
      |> then(fn req ->
        Supabase.Fetcher.Request.with_query(req, %{"project_id" => "not.is.null"})
      end)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    case result do
      {:ok, %{body: [item]}} when not is_nil(item) ->
        duration = item["duration_seconds"] || 0
        media_urls = item["media_urls"] || []
        project_id = item["project_id"]

        # Fetch project
        {:ok, project_resp} =
          Supabase.PostgREST.from(client(), "projects")
          |> Supabase.PostgREST.select(["title", "banner_url"])
          |> Supabase.PostgREST.eq("id", project_id)
          |> Map.put(:method, :get)
          |> Supabase.PostgREST.execute()

        {project_title, project_banner} =
          case project_resp.body do
            [p] -> {p["title"] || "Unknown", p["banner_url"]}
            _ -> {"Unknown", nil}
          end

        # Fetch user
        user_id = get_user_id(project_id)

        {user_avatar, user_display_name} =
          if user_id do
            case get_user_info(user_id) do
              [u] -> {u.avatar_url, u.display_name || "Unknown User"}
              _ -> {nil, "Unknown User"}
            end
          else
            {nil, "Unknown User"}
          end

        %{
          id: item["id"],
          body: item["body"],
          total_hours: div(duration, 3600),
          comments_count: item["comments_count"] || 0,
          created_at: item["created_at"],
          media_urls: media_urls,
          project_id: project_id,
          project_title: project_title,
          project_banner: project_banner,
          project_avatar: user_avatar,
          user_id: user_id,
          user_avatar: user_avatar,
          user_display_name: user_display_name
        }

      _ ->
        nil
    end
  end

  def random_devlogs do
    max_id = get_max_devlog_id()

    if max_id == 0 do
      []
    else
      # We need 25 devlogs, but some IDs might be missing or without project_id
      # Generate more IDs to ensure we get 25 valid ones.
      random_ids =
        1..200
        |> Enum.map(fn _ -> :rand.uniform(max_id) end)
        |> Enum.uniq()

      random_ids
      |> Enum.reduce_while([], fn id, acc ->
        if length(acc) >= 25 do
          {:halt, acc}
        else
          devlog =
            Cachex.fetch!(
              :random_devlog_cache,
              to_string(id),
              fn _key ->
                fetch_and_format_devlog(id)
              end,
              expiration: :timer.minutes(30)
            )

          if devlog do
            {:cont, [devlog | acc]}
          else
            {:cont, acc}
          end
        end
      end)
      |> Enum.sort_by(fn devlog -> devlog.created_at end, :desc)
    end
  end
end

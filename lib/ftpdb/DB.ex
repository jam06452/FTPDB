defmodule Ftpdb.DB do
  require Logger

  @random_project_batch_size 100
  @random_devlog_batch_size 100
  @random_project_cache_ttl :timer.minutes(30)
  @default_project_banner_url "https://flavortown.hackclub.com/assets/default-banner-3d4e1b67.png"

  def client do
    config = Application.get_env(:ftpdb, :supabase)
    {:ok, client} = Supabase.init_client(config[:url], config[:key])
    client
  end

  def warm_random_caches do
    [
      {:random_project_cache, random_project_batch_key(0),
       fn -> fetch_recent_project_batch(0) end},
      {:random_devlog_cache, random_devlog_batch_key(0), fn -> fetch_recent_devlog_batch(0) end}
    ]
    |> Task.async_stream(
      fn {cache_name, key, fetcher} ->
        Cachex.fetch!(
          cache_name,
          key,
          fn _key -> fetcher.() end,
          expiration: @random_project_cache_ttl
        )
      end,
      max_concurrency: 2,
      ordered: false,
      timeout: :infinity
    )
    |> Stream.run()

    :ok
  rescue
    exception ->
      Logger.warning("Failed to warm random caches on startup: #{Exception.message(exception)}")
      :ok
  end

  defp project_duration_fields(duration_seconds) do
    duration_seconds = duration_seconds || 0

    %{
      total_duration_seconds: duration_seconds,
      total_hours: div(duration_seconds, 3600)
    }
  end

  defp exclude_deleted_projects(query) do
    Supabase.PostgREST.any_of(query, "ship_status.is.null,ship_status.neq.deleted")
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
      |> exclude_deleted_projects()
      |> Supabase.PostgREST.order("stat_hot_score", desc: true)
      |> Supabase.PostgREST.limit(15)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    projects_with_banner =
      response.body
      |> Enum.filter(fn item ->
        user_id = get_user_id(item["id"])
        user_id != nil
      end)
      |> Enum.filter(fn item ->
        banner_url = item["banner_url"]
        banner_url != nil && banner_url != "" && banner_url != @default_project_banner_url
      end)
      |> Enum.take(10)
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

    projects_with_default_banner =
      response.body
      |> Enum.filter(fn item ->
        user_id = get_user_id(item["id"])
        user_id != nil
      end)
      |> Enum.filter(fn item ->
        banner_url = item["banner_url"]
        banner_url == @default_project_banner_url
      end)
      |> Enum.take(10)
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

    projects_with_banner ++ projects_with_default_banner
  end

  def top_this_week do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select(["title", "id", "stat_weekly_rank", "banner_url"])
      |> exclude_deleted_projects()
      |> Supabase.PostgREST.order("stat_weekly_rank", asc: true)
      |> Supabase.PostgREST.limit(20)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    projects_with_banner =
      response.body
      |> Enum.filter(fn item ->
        user_id = get_user_id(item["id"])
        user_id != nil
      end)
      |> Enum.filter(fn item ->
        banner_url = item["banner_url"]
        banner_url != nil && banner_url != "" && banner_url != @default_project_banner_url
      end)
      |> Enum.take(10)
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

    projects_with_default_banner =
      response.body
      |> Enum.filter(fn item ->
        user_id = get_user_id(item["id"])
        user_id != nil
      end)
      |> Enum.filter(fn item ->
        banner_url = item["banner_url"]
        banner_url == @default_project_banner_url
      end)
      |> Enum.take(10)
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

    projects_with_banner ++ projects_with_default_banner
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
      |> exclude_deleted_projects()
      |> Supabase.PostgREST.order("stat_total_likes", desc: true)
      |> Supabase.PostgREST.limit(15)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    projects_with_banner =
      response.body
      |> Enum.filter(fn item ->
        user_id = get_user_id(item["id"])
        user_id != nil
      end)
      |> Enum.filter(fn item ->
        banner_url = item["banner_url"]
        banner_url != nil && banner_url != "" && banner_url != @default_project_banner_url
      end)
      |> Enum.take(10)
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

    projects_with_default_banner =
      response.body
      |> Enum.filter(fn item ->
        user_id = get_user_id(item["id"])
        user_id != nil
      end)
      |> Enum.filter(fn item ->
        banner_url = item["banner_url"]
        banner_url == @default_project_banner_url
      end)
      |> Enum.take(10)
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

    projects_with_banner ++ projects_with_default_banner
  end

  def top_all_time do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select(["title", "id", "stat_all_time_rank", "banner_url"])
      |> exclude_deleted_projects()
      |> Supabase.PostgREST.order("stat_all_time_rank", asc: true)
      |> Supabase.PostgREST.limit(15)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    projects_with_banner =
      response.body
      |> Enum.filter(fn item ->
        user_id = get_user_id(item["id"])
        user_id != nil
      end)
      |> Enum.filter(fn item ->
        banner_url = item["banner_url"]
        banner_url != nil && banner_url != "" && banner_url != @default_project_banner_url
      end)
      |> Enum.take(10)
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

    projects_with_default_banner =
      response.body
      |> Enum.filter(fn item ->
        user_id = get_user_id(item["id"])
        user_id != nil
      end)
      |> Enum.filter(fn item ->
        banner_url = item["banner_url"]
        banner_url == @default_project_banner_url
      end)
      |> Enum.take(10)
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

    projects_with_banner ++ projects_with_default_banner
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

  def random_projects(limit \\ 10, excluded_project_ids \\ [])

  def random_projects(limit, excluded_project_ids)
      when is_integer(limit) and limit > 0 and is_list(excluded_project_ids) do
    excluded_project_ids =
      excluded_project_ids
      |> Enum.map(&to_string/1)
      |> MapSet.new()

    limit
    |> build_random_project_pool(0, [], excluded_project_ids)
    |> Enum.take_random(limit)
  end

  def random_projects(_limit, _excluded_project_ids), do: []

  defp build_random_project_pool(limit, _batch_index, acc, _excluded_project_ids)
       when length(acc) >= limit,
       do: acc

  defp build_random_project_pool(limit, batch_index, acc, excluded_project_ids) do
    batch =
      Cachex.fetch!(
        :random_project_cache,
        random_project_batch_key(batch_index),
        fn _key -> fetch_recent_project_batch(batch_index) end,
        expiration: @random_project_cache_ttl
      )

    case batch do
      :end_of_results ->
        acc

      [] ->
        build_random_project_pool(limit, batch_index + 1, acc, excluded_project_ids)

      projects ->
        filtered_projects =
          Enum.reject(projects, fn project ->
            MapSet.member?(excluded_project_ids, to_string(project.id))
          end)

        build_random_project_pool(
          limit,
          batch_index + 1,
          acc ++ filtered_projects,
          excluded_project_ids
        )
    end
  end

  defp random_project_batch_key(batch_index), do: "recent_projects_batch:#{batch_index}"

  defp fetch_recent_project_batch(batch_index) do
    start_index = batch_index * @random_project_batch_size
    end_index = start_index + @random_project_batch_size - 1

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
      |> Supabase.PostgREST.order("id", desc: true)
      |> Supabase.PostgREST.range(start_index, end_index)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    case List.wrap(response.body) do
      [] ->
        :end_of_results

      projects ->
        projects
        |> Task.async_stream(&format_recent_project_for_random/1,
          max_concurrency: System.schedulers_online() * 2,
          ordered: false,
          timeout: :infinity
        )
        |> Enum.reduce([], fn
          {:ok, nil}, acc ->
            acc

          {:ok, project}, acc ->
            [project | acc]

          {:exit, reason}, acc ->
            Logger.warning(
              "Failed to build random project batch #{batch_index}: #{inspect(reason)}"
            )

            acc
        end)
        |> Enum.reverse()
    end
  end

  defp format_recent_project_for_random(item) do
    banner_url = item["banner_url"]

    if is_nil(banner_url) or banner_url == @default_project_banner_url do
      nil
    else
      user_id = cached_user_id(item["id"])

      {user_avatar, user_display_name} =
        if user_id do
          case cached_user_info(user_id) do
            [user_info] -> {user_info.avatar_url, user_info.display_name || "Unknown User"}
            _ -> {nil, "Unknown User"}
          end
        else
          {nil, "Unknown User"}
        end

      duration = item["stat_total_duration_seconds"] || 0

      %{
        id: to_string(item["id"]),
        title: item["title"],
        banner_url: banner_url,
        display_name: user_display_name,
        avatar_url: user_avatar,
        stat_hot_score: item["stat_hot_score"] || 0,
        stat_total_likes: item["stat_total_likes"] || 0,
        total_duration_seconds: duration,
        total_hours: div(duration, 3600)
      }
    end
  end

  defp cached_user_id(project_id) do
    Cachex.fetch!(
      :user_id_cache,
      to_string(project_id),
      fn _key -> get_user_id(project_id) end,
      expiration: @random_project_cache_ttl
    )
  end

  defp cached_user_info(user_id) do
    Cachex.fetch!(
      :user_cache,
      to_string(user_id),
      fn _key -> get_user_info(user_id) end,
      expiration: @random_project_cache_ttl
    )
  end

  def search_projects(query) when is_binary(query) do
    cleaned_query = String.trim(query) |> String.downcase()

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
    cleaned_query = String.trim(query) |> String.downcase()

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

  def random_devlogs(limit \\ 25, excluded_devlog_ids \\ [])

  def random_devlogs(limit, excluded_devlog_ids)
      when is_integer(limit) and limit > 0 and is_list(excluded_devlog_ids) do
    excluded_devlog_ids =
      excluded_devlog_ids
      |> Enum.map(&to_string/1)
      |> MapSet.new()

    limit
    |> build_random_devlog_pool(0, [], excluded_devlog_ids)
    |> Enum.take_random(limit)
  end

  def random_devlogs(_limit, _excluded_devlog_ids), do: []

  defp build_random_devlog_pool(limit, _batch_index, acc, _excluded_devlog_ids)
       when length(acc) >= limit,
       do: acc

  defp build_random_devlog_pool(limit, batch_index, acc, excluded_devlog_ids) do
    batch =
      Cachex.fetch!(
        :random_devlog_cache,
        random_devlog_batch_key(batch_index),
        fn _key -> fetch_recent_devlog_batch(batch_index) end,
        expiration: @random_project_cache_ttl
      )

    case batch do
      :end_of_results ->
        acc

      [] ->
        build_random_devlog_pool(limit, batch_index + 1, acc, excluded_devlog_ids)

      devlogs ->
        filtered_devlogs =
          Enum.reject(devlogs, fn devlog ->
            MapSet.member?(excluded_devlog_ids, to_string(devlog.id))
          end)

        build_random_devlog_pool(
          limit,
          batch_index + 1,
          acc ++ filtered_devlogs,
          excluded_devlog_ids
        )
    end
  end

  defp random_devlog_batch_key(batch_index), do: "recent_devlogs_batch:#{batch_index}"

  defp fetch_recent_devlog_batch(batch_index) do
    start_index = batch_index * @random_devlog_batch_size
    end_index = start_index + @random_devlog_batch_size - 1

    {:ok, response} =
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
      |> then(fn req ->
        Supabase.Fetcher.Request.with_query(req, %{"project_id" => "not.is.null"})
      end)
      |> Supabase.PostgREST.order("created_at", desc: true)
      |> Supabase.PostgREST.range(start_index, end_index)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    case List.wrap(response.body) do
      [] ->
        :end_of_results

      devlogs ->
        devlogs
        |> Task.async_stream(&format_recent_devlog_for_random/1,
          max_concurrency: System.schedulers_online() * 2,
          ordered: false,
          timeout: :infinity
        )
        |> Enum.reduce([], fn
          {:ok, nil}, acc ->
            acc

          {:ok, devlog}, acc ->
            [devlog | acc]

          {:exit, reason}, acc ->
            Logger.warning(
              "Failed to build random devlog batch #{batch_index}: #{inspect(reason)}"
            )

            acc
        end)
        |> Enum.reverse()
    end
  end

  defp format_recent_devlog_for_random(item) do
    duration = item["duration_seconds"] || 0
    media_urls = item["media_urls"] || []
    project_id = item["project_id"]

    with project_id when not is_nil(project_id) <- project_id,
         %{title: project_title, banner_url: project_banner} <-
           cached_random_devlog_project(project_id) do
      user_id = cached_user_id(project_id)

      {user_avatar, user_display_name} =
        if user_id do
          case cached_user_info(user_id) do
            [user_info] -> {user_info.avatar_url, user_info.display_name || "Unknown User"}
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
    else
      _ -> nil
    end
  end

  defp cached_random_devlog_project(project_id) do
    Cachex.fetch!(
      :random_devlog_cache,
      "devlog_project_summary:#{project_id}",
      fn _key -> fetch_random_devlog_project(project_id) end,
      expiration: @random_project_cache_ttl
    )
  end

  defp fetch_random_devlog_project(project_id) do
    {:ok, response} =
      Supabase.PostgREST.from(client(), "projects")
      |> Supabase.PostgREST.select(["title", "banner_url"])
      |> Supabase.PostgREST.eq("id", project_id)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    case response.body do
      [project] ->
        %{
          title: project["title"] || "Unknown",
          banner_url: project["banner_url"]
        }

      _ ->
        nil
    end
  end

  def true_random() do
  {:ok, %{body: body}} = Supabase.PostgREST.rpc(client(), "get_random_project", %{})
    |> Supabase.PostgREST.single()
    |> Supabase.PostgREST.execute()

  body
  end
end

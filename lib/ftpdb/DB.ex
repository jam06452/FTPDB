defmodule Ftpdb.DB do
  require Logger

  def client do
    config = Application.get_env(:ftpdb, :supabase)
    {:ok, client} = Supabase.init_client(config[:url], config[:key])
    client
  end

  def hot do
    case Supabase.PostgREST.from(client(), "projects")
         |> Supabase.PostgREST.select([
           "title",
           "id",
           "banner_url",
           "stat_total_duration_seconds"
         ])
         |> Supabase.PostgREST.order("stat_hot_score", desc: true)
         |> Supabase.PostgREST.limit(10)
         |> Map.put(:method, :get)
         |> Supabase.PostgREST.execute() do
      {:ok, response} ->
        response.body
        |> Enum.map(fn item ->
          user_id = get_user_id(item["id"])
          user_info = if user_id, do: get_user_info(user_id), else: nil

          case user_info do
            [info] ->
              duration = item["stat_total_duration_seconds"] || 0

              project_map = %{
                title: item["title"],
                banner_url: item["banner_url"],
                total_hours: div(duration, 3600)
              }

              {to_string(item["id"]), Map.merge(info, project_map)}

            _ ->
              nil
          end
        end)
        |> Enum.filter(& &1)
        |> Map.new()

      {:error, error} ->
        Logger.error("Failed to get hot projects: #{inspect(error)}")
        %{}
    end
  end

  def top_this_week do
    case Supabase.PostgREST.from(client(), "projects")
         |> Supabase.PostgREST.select(["title", "id", "stat_weekly_rank", "banner_url"])
         |> Supabase.PostgREST.order("stat_weekly_rank", asc: true)
         |> Supabase.PostgREST.limit(10)
         |> Map.put(:method, :get)
         |> Supabase.PostgREST.execute() do
      {:ok, response} ->
        response.body
        |> Enum.map(fn item ->
          user_id = get_user_id(item["id"])
          user_info = if user_id, do: get_user_info(user_id), else: nil

          case user_info do
            [info] ->
              user_map = %{
                id: to_string(item["id"]),
                title: item["title"],
                rank: item["stat_weekly_rank"],
                banner_url: item["banner_url"]
              }

              Map.merge(info, user_map)

            _ ->
              nil
          end
        end)
        |> Enum.filter(& &1)

      {:error, error} ->
        Logger.error("Failed to get top_this_week: #{inspect(error)}")
        []
    end
  end

  def fan_favourites do
    case Supabase.PostgREST.from(client(), "projects")
         |> Supabase.PostgREST.select(["title", "id", "banner_url"])
         |> Supabase.PostgREST.order("stat_total_likes", desc: true)
         |> Supabase.PostgREST.limit(10)
         |> Map.put(:method, :get)
         |> Supabase.PostgREST.execute() do
      {:ok, response} ->
        response.body
        |> Enum.map(fn item ->
          user_id = get_user_id(item["id"])
          user_info = if user_id, do: get_user_info(user_id), else: nil

          case user_info do
            [info] ->
              project_map = %{title: item["title"], banner_url: item["banner_url"]}
              {to_string(item["id"]), Map.merge(info, project_map)}

            _ ->
              nil
          end
        end)
        |> Enum.filter(& &1)
        |> Map.new()

      {:error, error} ->
        Logger.error("Failed to get fan_favourites: #{inspect(error)}")
        %{}
    end
  end

  def top_all_time do
    case Supabase.PostgREST.from(client(), "projects")
         |> Supabase.PostgREST.select(["title", "id", "stat_all_time_rank", "banner_url"])
         |> Supabase.PostgREST.order("stat_all_time_rank", asc: true)
         |> Supabase.PostgREST.limit(10)
         |> Map.put(:method, :get)
         |> Supabase.PostgREST.execute() do
      {:ok, response} ->
        response.body
        |> Enum.map(fn item ->
          user_id = get_user_id(item["id"])
          user_info = if user_id, do: get_user_info(user_id), else: nil

          case user_info do
            [info] ->
              user_map = %{
                id: to_string(item["id"]),
                title: item["title"],
                rank: item["stat_all_time_rank"],
                banner_url: item["banner_url"]
              }

              Map.merge(info, user_map)

            _ ->
              nil
          end
        end)
        |> Enum.filter(& &1)

      {:error, error} ->
        Logger.error("Failed to get top_all_time: #{inspect(error)}")
        []
    end
  end

  def most_time_spent do
    case Supabase.PostgREST.from(client(), "users")
         |> Supabase.PostgREST.select(["id", "display_name", "avatar_url", "total_time"])
         |> Supabase.PostgREST.order("total_time", desc: true)
         |> Supabase.PostgREST.limit(10)
         |> Map.put(:method, :get)
         |> Supabase.PostgREST.execute() do
      {:ok, response} ->
        response.body
        |> Enum.map(fn item ->
          total_time = item["total_time"] || 0
          total_hours = div(total_time, 3600)

          %{
            id: to_string(item["id"]),
            display_name: item["display_name"],
            avatar_url: item["avatar_url"],
            total_hours: total_hours
          }
        end)

      {:error, error} ->
        Logger.error("Failed to get most_time_spent: #{inspect(error)}")
        []
    end
  end

  def get_project_info(project_id) do
    case Supabase.PostgREST.from(client(), "projects")
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
         |> Supabase.PostgREST.execute() do
      {:ok, response} ->
        user_id = get_user_id(project_id)
        user_info = if user_id, do: get_user_info(user_id), else: nil

        response.body
        |> Enum.map(fn item ->
          case user_info do
            [info] ->
              duration = item["stat_total_duration_seconds"] || 0
              total_hours = div(duration, 3600)
              user_info_filtered = Map.drop(info, [:total_hours])

              project_map = %{
                title: item["title"],
                description: item["description"],
                repo_url: item["repo_url"],
                demo_url: item["demo_url"],
                ship_status: item["ship_status"],
                total_hours: total_hours,
                total_likes: item["stat_total_likes"],
                banner_url: item["banner_url"]
              }

              Map.merge(user_info_filtered, project_map)

            _ ->
              nil
          end
        end)
        |> Enum.filter(& &1)

      {:error, error} ->
        Logger.error("Failed to get project info for project_id #{project_id}: #{inspect(error)}")
        []
    end
  end

  def random_projects do
    case Supabase.PostgREST.from(client(), "projects")
         |> Supabase.PostgREST.select([
           "id",
           "title",
           "stat_total_duration_seconds",
           "stat_total_likes",
           "stat_hot_score"
         ])
         |> Map.put(:method, :get)
         |> Supabase.PostgREST.execute() do
      {:ok, response} ->
        response.body
        |> Enum.map(fn item ->
          user_id = get_user_id(item["id"])
          user_info = if user_id, do: get_user_info(user_id), else: nil

          case user_info do
            [info] ->
              project_map = %{
                id: to_string(item["id"]),
                title: item["title"],
                total_hours: div(item["stat_total_duration_seconds"] || 0, 3600),
                likes: item["stat_total_likes"] || 0,
                hot_score: item["stat_hot_score"] || 0
              }

              Map.merge(info, project_map)

            _ ->
              nil
          end
        end)
        |> Enum.filter(& &1)

      {:error, error} ->
        Logger.error("Failed to get random projects: #{inspect(error)}")
        []
    end
  end

  def search_projects(query) when is_binary(query) do
    cleaned_query = String.trim(query)

    if String.length(cleaned_query) == 0 do
      []
    else
      search_term = "%#{cleaned_query}%"

      case Supabase.PostgREST.from(client(), "projects")
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
           |> Supabase.PostgREST.execute() do
        {:ok, response} ->
          response.body
          |> Enum.map(fn item ->
            user_id = get_user_id(item["id"])
            user_info = if user_id, do: get_user_info(user_id), else: nil

            case user_info do
              [info] ->
                project_map = %{
                  id: to_string(item["id"]),
                  title: item["title"],
                  banner_url: item["banner_url"],
                  hot_score: item["stat_hot_score"] || 0,
                  likes: item["stat_total_likes"] || 0
                }

                Map.merge(info, project_map)

              _ ->
                nil
            end
          end)
          |> Enum.filter(& &1)
          |> Enum.sort_by(fn item ->
            # Sort by a weighted combination: 60% hot score, 40% likes
            # Normalize likes to be within reasonable range (divide by 100)
            hot = item.hot_score * 0.6
            likes = item.likes / 100 * 0.4
            -(hot + likes)
          end)

        {:error, error} ->
          Logger.error("Failed to search projects for query '#{query}': #{inspect(error)}")
          []
      end
    end
  end

  def get_user_id(project_id) do
    case Supabase.PostgREST.from(client(), "user_projects")
         |> Supabase.PostgREST.select(["user_id"])
         |> Supabase.PostgREST.eq("project_id", project_id)
         |> Map.put(:method, :get)
         |> Supabase.PostgREST.execute() do
      {:ok, response} ->
        case response.body do
          [%{"user_id" => user_id}] -> user_id
          [] -> nil
        end

      {:error, error} ->
        Logger.error("Failed to get user_id for project_id #{project_id}: #{inspect(error)}")
        nil
    end
  end

  def get_user_info(user_id) do
    case Supabase.PostgREST.from(client(), "users")
         |> Supabase.PostgREST.select([
           "id",
           "display_name",
           "avatar_url",
           "total_time",
           "slack_id"
         ])
         |> Supabase.PostgREST.eq("id", user_id)
         |> Map.put(:method, :get)
         |> Supabase.PostgREST.execute() do
      {:ok, response} ->
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

      {:error, error} ->
        Logger.error("Failed to get user info for user_id #{user_id}: #{inspect(error)}")
        []
    end
  end

  def search_users(query, min_hours \\ 0) when is_binary(query) do
    cleaned_query = String.trim(query)

    if String.length(cleaned_query) == 0 do
      []
    else
      search_term = "%#{cleaned_query}%"

      case Supabase.PostgREST.from(client(), "users")
           |> Supabase.PostgREST.select([
             "id",
             "display_name",
             "avatar_url",
             "total_time"
           ])
           |> Supabase.PostgREST.ilike("display_name", search_term)
           |> Supabase.PostgREST.limit(100)
           |> Map.put(:method, :get)
           |> Supabase.PostgREST.execute() do
        {:ok, response} ->
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

        {:error, error} ->
          Logger.error("Failed to search users for query '#{query}': #{inspect(error)}")
          []
      end
    end
  end

  def get_user_projects(user_id) do
    case Supabase.PostgREST.from(client(), "user_projects")
         |> Supabase.PostgREST.select(["project_id"])
         |> Supabase.PostgREST.eq("user_id", user_id)
         |> Map.put(:method, :get)
         |> Supabase.PostgREST.execute() do
      {:ok, response} ->
        project_ids =
          response.body
          |> Enum.map(fn item -> item["project_id"] end)

        if Enum.empty?(project_ids) do
          []
        else
          case Supabase.PostgREST.from(client(), "projects")
               |> Supabase.PostgREST.select([
                 "id",
                 "title",
                 "banner_url",
                 "stat_total_duration_seconds",
                 "stat_total_likes"
               ])
               |> Map.put(:method, :get)
               |> Supabase.PostgREST.execute() do
            {:ok, projects_response} ->
              # Filter locally and sort by hours
              all_projects = projects_response.body || []

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

            {:error, error} ->
              Logger.error("Failed to get projects for user_id #{user_id}: #{inspect(error)}")
              []
          end
        end

      {:error, error} ->
        Logger.error("Failed to get user_projects for user_id #{user_id}: #{inspect(error)}")
        []
    end
  end

  def get_devlogs(project_id) do
    case Supabase.PostgREST.from(client(), "devlogs")
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
         |> Supabase.PostgREST.execute() do
      {:ok, response} ->
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

      {:error, error} ->
        Logger.error("Failed to get devlogs for project_id #{project_id}: #{inspect(error)}")
        []
    end
  end

  def random_devlogs do
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
      |> Supabase.PostgREST.order("created_at", desc: true)
      |> Supabase.PostgREST.limit(100)
      |> Map.put(:method, :get)
      |> Supabase.PostgREST.execute()

    devlogs =
      case result do
        {:ok, response} ->
          response.body || []

        {:error, error} ->
          Logger.error("Error fetching devlogs: #{inspect(error)}")
          []
      end

    if Enum.empty?(devlogs) do
      []
    else
      # Fetch all user_projects mappings in one query
      user_projects_result =
        Supabase.PostgREST.from(client(), "user_projects")
        |> Supabase.PostgREST.select(["project_id", "user_id"])
        |> Map.put(:method, :get)
        |> Supabase.PostgREST.execute()

      user_projects_map =
        case user_projects_result do
          {:ok, response} ->
            (response.body || [])
            |> Map.new(fn item -> {item["project_id"], item["user_id"]} end)

          {:error, error} ->
            Logger.error("Error fetching user_projects: #{inspect(error)}")
            %{}
        end

      # Fetch all projects in one query
      projects_result =
        Supabase.PostgREST.from(client(), "projects")
        |> Supabase.PostgREST.select(["id", "title"])
        |> Map.put(:method, :get)
        |> Supabase.PostgREST.execute()

      projects_map =
        case projects_result do
          {:ok, response} ->
            (response.body || [])
            |> Map.new(fn item -> {item["id"], item["title"]} end)

          {:error, error} ->
            Logger.error("Error fetching projects: #{inspect(error)}")
            %{}
        end

      # Fetch all users in one query
      users_result =
        Supabase.PostgREST.from(client(), "users")
        |> Supabase.PostgREST.select(["id", "avatar_url", "display_name"])
        |> Map.put(:method, :get)
        |> Supabase.PostgREST.execute()

      users_map =
        case users_result do
          {:ok, response} ->
            (response.body || [])
            |> Map.new(fn item ->
              {item["id"],
               %{"avatar_url" => item["avatar_url"], "display_name" => item["display_name"]}}
            end)

          {:error, error} ->
            Logger.error("Error fetching users: #{inspect(error)}")
            %{}
        end

      # Calculate weights with exponential bias towards newer devlogs
      weighted_devlogs =
        devlogs
        |> Enum.with_index()
        |> Enum.map(fn {item, index} ->
          # Exponential decay: newer items get much higher weights
          # weight = e^(-index/decay_rate)
          weight = :math.exp(-index / 3.0)

          duration = item["duration_seconds"] || 0
          media_urls = item["media_urls"] || []
          project_id = item["project_id"]

          user_id = Map.get(user_projects_map, project_id)
          project_title = Map.get(projects_map, project_id, "Unknown")
          user_data = if user_id, do: Map.get(users_map, user_id, %{}), else: %{}
          user_avatar = Map.get(user_data, "avatar_url", nil)

          user_display_name =
            case Map.get(user_data, "display_name") do
              nil -> "Unknown User"
              "" -> "Unknown User"
              name -> name
            end

          devlog = %{
            id: item["id"],
            body: item["body"],
            total_hours: div(duration, 3600),
            comments_count: item["comments_count"] || 0,
            created_at: item["created_at"],
            media_urls: media_urls,
            project_id: project_id,
            project_title: project_title,
            user_id: user_id,
            user_avatar: user_avatar,
            user_display_name: user_display_name,
            weight: weight
          }

          {devlog, weight}
        end)

      if Enum.empty?(weighted_devlogs) do
        []
      else
        # Perform weighted random selection
        total_weight = weighted_devlogs |> Enum.map(fn {_, w} -> w end) |> Enum.sum()

        selected_count = min(10, length(weighted_devlogs))

        selected =
          1..selected_count
          |> Enum.reduce([], fn _i, acc ->
            rand = :rand.uniform() * total_weight

            {selected_devlog, _weight} =
              weighted_devlogs
              |> Enum.reduce_while({nil, 0}, fn {devlog, weight}, {_last, cum_weight} ->
                new_cum = cum_weight + weight

                if new_cum >= rand,
                  do: {:halt, {devlog, new_cum}},
                  else: {:cont, {devlog, new_cum}}
              end)

            acc ++ [selected_devlog]
          end)

        # Deduplicate by devlog ID and return sorted by date (newest first)
        selected
        |> Enum.uniq_by(fn devlog -> devlog.id end)
        |> Enum.map(fn devlog -> Map.drop(devlog, [:weight]) end)
        |> Enum.sort_by(fn devlog -> devlog.created_at end, :desc)
      end
    end
  end
end

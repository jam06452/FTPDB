defmodule FtpdbWeb.ApiController do
  use FtpdbWeb, :controller

  def hot do
    hot = Cachex.fetch!(:hot_cache, "hot", fn _key -> Ftpdb.DB.hot() end)
    json(conn, hot)
  end

  def top_this_week do
    top_this_week =
      Cachex.fetch!(:top_week_cache, "top_this_week", fn _key -> Ftpdb.DB.top_this_week() end)

    json(conn, top_this_week)
  end

  def fan_favourites do
    fan_favourites =
      Cachex.fetch!(:fan_favourites_cache, "fan_favourites", fn _key ->
        Ftpdb.DB.fan_favourites()
      end)

    json(conn, fan_favourites)
  end

  def top_all_time do
    top_all_time =
      Cachex.fetch!(:top_all_time_cache, "top_all_time", fn _key -> Ftpdb.DB.top_all_time() end)

    json(conn, top_all_time)
  end

  def most_time_spent do
    most_time_spent =
      Cachex.fetch!(:most_time_spent_cache, "most_time_spent", fn _key ->
        Ftpdb.DB.most_time_spent()
      end)

    json(conn, most_time_spent)
  end

  def devlogs(id) do
    devlog =
      Cachex.fetch!(:devlog_cache, id, fn _key -> Ftpdb.DB.get_devlogs(id) end,
        expiration: :timer.minutes(60)
      )

    json(conn, devlog)
  end

  def project_info(id) do
    project_info =
      Cachex.fetch!(:project_cache, id, fn _key -> Ftpdb.DB.get_project_info(id) end,
        expiration: :timer.minutes(60)
      )

    json(conn, project_info)
  end

  def user_info(id) do
    id = to_string(id)

    user_info =
      Cachex.fetch!(:user_cache, id, fn _key -> Ftpdb.DB.get_user_info(id) end,
        expiration: :timer.minutes(60)
      )

    json(conn, List.first(user_info))
  end

  def search(query) do
    min_hours =
      case params["min_hours"] do
        nil ->
          0

        hours_str ->
          case Integer.parse(hours_str) do
            {hours, _} when hours >= 0 -> hours
            _ -> 0
          end
      end

    json(conn, %{
      projects: Ftpdb.DB.search_projects(query),
      users: Ftpdb.DB.search_users(query, min_hours)
    })
  end

  def suggest(conn, %{
        "category" => category,
        "display_name" => display_name,
        "message" => message,
        "title" => title
      }) do
    json(conn, Ftpdb.Slack.suggest(category, display_name, message, title))
  end

  def random_projects(conn, %{"filter" => filter}) do
    case filter do
      "stat_hot_score" ->
        hot(conn, %{})

      "stat_total_likes" ->
        fan_favourites(conn, %{})

      "stat_total_duration_seconds" ->
        most_time_spent(conn, %{})

      _ ->
        json(conn, Ftpdb.DB.random_projects())
    end
  end

  def random_projects(conn, _params) do
    json(conn, Ftpdb.DB.random_projects())
  end

  def user_projects(conn, %{"user_id" => user_id}) do
    projects = Ftpdb.DB.get_user_projects(user_id)
    json(conn, projects)
  end
end

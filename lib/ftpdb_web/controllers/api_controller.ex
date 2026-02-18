defmodule FtpdbWeb.ApiController do
  use FtpdbWeb, :controller

  def hot(conn, _params) do
    hot = Cachex.fetch!(:hot_cache, "hot", fn _key -> Ftpdb.DB.hot() end)
    json(conn, hot)
  end

  def top_this_week(conn, _params) do
    top_this_week =
      Cachex.fetch!(:top_week_cache, "top_this_week", fn _key -> Ftpdb.DB.top_this_week() end)

    json(conn, top_this_week)
  end

  def fan_favourites(conn, _params) do
    fan_favourites =
      Cachex.fetch!(:fan_favourites_cache, "fan_favourites", fn _key ->
        Ftpdb.DB.fan_favourites()
      end)

    json(conn, fan_favourites)
  end

  def top_all_time(conn, _params) do
    top_all_time =
      Cachex.fetch!(:top_all_time_cache, "top_all_time", fn _key -> Ftpdb.DB.top_all_time() end)

    json(conn, top_all_time)
  end

  def most_time_spent(conn, _params) do
    most_time_spent =
      Cachex.fetch!(:most_time_spent_cache, "most_time_spent", fn _key ->
        Ftpdb.DB.most_time_spent()
      end)

    json(conn, most_time_spent)
  end

  def devlogs(conn, %{"id" => id}) do
    devlog =
      Cachex.fetch!(:devlog_cache, id, fn _key -> Ftpdb.DB.get_devlogs(id) end,
        expiration: :timer.minutes(60)
      )

    json(conn, devlog)
  end

  def project_info(conn, %{"id" => id}) do
    project_info =
      Cachex.fetch!(:project_cache, id, fn _key -> Ftpdb.DB.get_project_info(id) end,
        expiration: :timer.minutes(60)
      )

    json(conn, project_info)
  end

  def user_info(conn, %{"id" => id}) do
    id = to_string(id)

    user_info =
      Cachex.fetch!(:user_cache, id, fn _key -> Ftpdb.DB.get_user_info(id) end,
        expiration: :timer.minutes(60)
      )

    json(conn, List.first(user_info))
  end

  def search(conn, %{"q" => query}) do
    json(conn, %{projects: Ftpdb.DB.search_projects(query), users: Ftpdb.DB.search_users(query)})
  end

  def search(conn, _params) do
    json(conn, %{projects: [], users: []})
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
    json(conn, Ftpdb.DB.random_projects(filter))
  end

  def random_projects(conn, _params) do
    json(conn, Ftpdb.DB.random_projects("random"))
  end
end

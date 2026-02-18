defmodule FtpdbWeb.ApiController do
  use FtpdbWeb, :controller

  def hot(conn, _params) do
    json(conn, Ftpdb.DB.hot())
  end

  def top_this_week(conn, _params) do
    json(conn, Ftpdb.DB.top_this_week())
  end

  def fan_favourites(conn, _params) do
    json(conn, Ftpdb.DB.fan_favourites())
  end

  def top_all_time(conn, _params) do
    json(conn, Ftpdb.DB.top_all_time())
  end

  def most_time_spent(conn, _params) do
    json(conn, Ftpdb.DB.most_time_spent())
  end

  def devlogs(conn, %{"id" => id}) do
    json(conn, Ftpdb.DB.get_devlogs(id))
  end

  def project_info(conn, %{"id" => id}) do
    json(conn, Ftpdb.DB.get_project_info(id))
  end

  def user_info(conn, %{"id" => id}) do
    json(conn, Ftpdb.DB.extended_user_info(id))
  end

  def search(conn, %{"q" => query}) do
    results = Ftpdb.DB.search_projects(query)
    json(conn, results)
  end

  def search(conn, _params) do
    json(conn, [])
  end
end

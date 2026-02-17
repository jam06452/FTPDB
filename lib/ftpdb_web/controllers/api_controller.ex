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
end

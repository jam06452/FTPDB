defmodule FtpdbWeb.PageController do
  use FtpdbWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

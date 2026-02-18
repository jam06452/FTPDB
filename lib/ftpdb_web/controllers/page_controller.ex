defmodule FtpdbWeb.PageController do
  use FtpdbWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def project(conn, %{"id" => id}) do
    render(conn, :project, project_id: id)
  end
end

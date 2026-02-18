defmodule FtpdbWeb.PageController do
  use FtpdbWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def project(conn, %{"id" => id}) do
    render(conn, :project, project_id: id)
  end

  def suggestions(conn, _params) do
    render(conn, :suggestions)
  end

  def projects(conn, _params) do
    render(conn, :projects)
  end
end

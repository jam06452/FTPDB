defmodule FtpdbWeb.NavbarComponent do
  @moduledoc """
  Shared navbar component for all pages.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: FtpdbWeb.Endpoint,
    router: FtpdbWeb.Router,
    statics: FtpdbWeb.static_paths()

  embed_templates "navbar_component/*"

  attr :current_section, :string,
    default: nil,
    doc: "the current section for nav pill active state"

  def navbar(assigns)
end

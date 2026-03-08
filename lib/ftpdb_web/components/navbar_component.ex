defmodule FtpdbWeb.NavbarComponent do
  @moduledoc """
  Shared navbar component for all pages.
  """
  use Phoenix.Component

  embed_templates "navbar_component/*"

  attr :logo_url, :string, default: "/images/logo.png", doc: "URL for the logo image"

  attr :current_section, :string,
    default: nil,
    doc: "the current section for nav pill active state"

  def navbar(assigns)
end

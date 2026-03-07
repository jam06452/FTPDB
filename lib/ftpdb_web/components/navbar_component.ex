defmodule FtpdbWeb.NavbarComponent do
  @moduledoc """
  Shared navbar component for all pages.
  """
  use Phoenix.Component

  embed_templates "navbar_component/*"

  attr :logo_text, :string, default: "FTPDB", doc: "text for the logo/home link"

  attr :current_section, :string,
    default: nil,
    doc: "the current section for nav pill active state"

  def navbar(assigns)
end

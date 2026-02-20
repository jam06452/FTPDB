defmodule FtpdbWeb.NavbarComponent do
  @moduledoc """
  Shared navbar component for all pages.
  """
  use Phoenix.Component

  @doc """
  Renders the shared navbar.

  ## Examples

      <.navbar back_link="/" />
      <.navbar search_enabled pills_enabled />
  """
  attr :logo_text, :string, default: "FTPDB"
  attr :back_link, :string, default: nil, doc: "Link for back button"
  attr :search_enabled, :boolean, default: false, doc: "Show search bar"
  attr :pills_enabled, :boolean, default: false, doc: "Show navigation pills"

  def navbar(assigns) do
    ~H"""
    <!-- ═══ NAVBAR ═══ -->
    <nav class="navbar">
      <a href="/" class="nav-logo">{@logo_text}</a>

      <%= if @back_link do %>
        <a href={@back_link} class="nav-back">
          <svg
            width="12"
            height="12"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
          >
            <path d="M15 18l-6-6 6-6" />
          </svg>
          Back
        </a>
      <% end %>

      <%= if @search_enabled do %>
        <div class="nav-search">
          <input
            type="search"
            id="searchInput"
            placeholder="Search projects, channels…"
            oninput="handleSearch(this.value)"
          />
          <svg
            class="nav-search-icon"
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
          </svg>
          <div class="search-autocomplete" id="searchAutocomplete"></div>
        </div>
      <% end %>

      <%= if @pills_enabled do %>
        <div class="nav-pills">
          <a href="/projects" class="nav-pill">Projects</a>
          <button class="nav-pill active" onclick="filterSection('top-week')">Top This Week</button>
          <button class="nav-pill" onclick="filterSection('hot')">Hot</button>
          <button class="nav-pill" onclick="filterSection('updates')">Updates</button>
          <a href="/suggestions" class="nav-pill">Suggestions</a>
          <a href="/docs" class="nav-pill">Docs</a>
        </div>
      <% end %>
    </nav>
    """
  end

  @doc """
  Shared navbar styles that should be included in all pages.
  Returns a string of CSS for the navbar.
  """
  def navbar_styles do
    """
    /* ─── NAVBAR ─── */
    .navbar {
      position: sticky;
      top: 0;
      z-index: 100;
      background: rgba(13,15,20,0.88);
      backdrop-filter: blur(16px);
      border-bottom: 1px solid var(--border);
      padding: 0 28px;
      height: 58px;
      display: flex;
      align-items: center;
      gap: 24px;
    }

    .nav-logo {
      font-family: 'DM Serif Display', serif;
      font-size: 22px;
      color: var(--gold);
      letter-spacing: -0.5px;
      white-space: nowrap;
      border: 2px solid var(--gold);
      border-radius: var(--r-sm);
      padding: 2px 10px;
      flex-shrink: 0;
      cursor: pointer;
      transition: opacity var(--transition);
    }

    .nav-logo:hover {
      opacity: 0.9;
    }

    .nav-back {
      display: flex;
      align-items: center;
      gap: 6px;
      font-family: 'DM Mono', monospace;
      font-size: 12px;
      color: var(--muted);
      padding: 5px 12px;
      border: 1px solid var(--border);
      border-radius: 50px;
      background: var(--surface);
      cursor: pointer;
      transition: color var(--transition), border-color var(--transition);
    }
    .nav-back:hover { color: var(--text); border-color: var(--gold-dim); }

    .nav-menu-btn {
      background: none;
      border: none;
      color: var(--text);
      cursor: pointer;
      display: flex;
      flex-direction: column;
      gap: 5px;
      padding: 4px;
    }
    .nav-menu-btn span {
      display: block;
      width: 22px;
      height: 2px;
      background: var(--text);
      border-radius: 2px;
      transition: var(--transition);
    }

    .nav-search {
      flex: 1;
      max-width: 480px;
      position: relative;
    }
    .nav-search input {
      width: 100%;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 50px;
      padding: 7px 40px 7px 16px;
      color: var(--text);
      font-family: 'DM Mono', monospace;
      font-size: 13px;
      outline: none;
      transition: border-color var(--transition);
    }
    .nav-search input::placeholder { color: var(--muted); }
    .nav-search input:focus { border-color: var(--accent); }
    .nav-search-icon {
      position: absolute;
      right: 12px;
      top: 50%;
      transform: translateY(-50%);
      color: var(--muted);
      pointer-events: none;
    }

    /* Autocomplete dropdown - Two column layout */
    .search-autocomplete {
      position: absolute;
      top: calc(100% + 8px);
      left: 0;
      right: 0;
      background: transparent;
      display: none;
      z-index: 1000;
      min-width: 800px;
      max-width: 100vw;
      width: max-content;
    }

    .search-autocomplete.active {
      display: flex;
      gap: 12px;
    }

    .search-autocomplete-section {
      flex: 1;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--r-md);
      box-shadow: 0 8px 24px rgba(0,0,0,0.3);
      overflow: hidden;
      display: flex;
      flex-direction: column;
      min-width: 300px;
      max-height: 480px;
      overflow-y: auto;
    }

    .search-autocomplete-section:empty {
      display: none;
    }

    .search-autocomplete-section-title {
      padding: 12px 14px;
      font-size: 11px;
      font-weight: 700;
      color: var(--muted);
      letter-spacing: 0.08em;
      text-transform: uppercase;
      background: var(--surface2);
      border-bottom: 1px solid var(--border);
      flex-shrink: 0;
    }

    .search-autocomplete-item {
      padding: 10px 14px;
      border-bottom: 1px solid var(--border);
      cursor: pointer;
      transition: background-color var(--transition);
      display: flex;
      gap: 10px;
      align-items: center;
    }

    .search-autocomplete-item:last-child {
      border-bottom: none;
    }

    .search-autocomplete-item:hover {
      background: var(--surface2);
    }

    .search-autocomplete-item-icon {
      width: 32px;
      height: 32px;
      flex-shrink: 0;
      border-radius: 4px;
      background: var(--surface2);
      border: 1px solid var(--border);
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .search-autocomplete-item-icon img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }

    .search-autocomplete-item-content {
      flex: 1;
      min-width: 0;
    }

    .search-autocomplete-item-title {
      font-size: 13px;
      font-weight: 600;
      color: var(--text);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .search-autocomplete-item-meta {
      font-family: 'DM Mono', monospace;
      font-size: 11px;
      color: var(--muted);
    }

    .search-autocomplete-empty {
      padding: 20px 14px;
      text-align: center;
      color: var(--muted);
      font-size: 12px;
    }

    .nav-pills {
      display: flex;
      gap: 6px;
      margin-left: auto;
    }
    .nav-pill {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 50px;
      padding: 5px 14px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      color: var(--muted);
      cursor: pointer;
      transition: color var(--transition), border-color var(--transition);
      white-space: nowrap;
    }
    .nav-pill:hover, .nav-pill.active {
      color: var(--gold);
      border-color: var(--gold-dim);
    }

    .nav-pills a.nav-pill {
      display: inline-flex;
      align-items: center;
      text-decoration: none;
    }

    .nav-spacer { flex: 1; }

    /* ─── RESPONSIVE ─── */
    @media (max-width: 768px) {
      .nav-pills { display: none; }
    }
    """
  end
end

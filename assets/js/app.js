// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/ftpdb"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    reloader.enableServerLogs()
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)
    window.liveReloader = reloader
  })
}

/* ══════════════════════════════════════════════════════════
   FTPDB SHARED UTILITIES
   ══════════════════════════════════════════════════════════ */

window.escapeHtml = (str) => {
  if (!str) return ""
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}

window.viewProject = (id) => { window.location.href = `/project/${id}` }
window.viewUser    = (id) => { window.location.href = `/user/${id}` }

/* ══════════════════════════════════════════════════════════
   SHARED SEARCH (used by home + projects pages)
   ══════════════════════════════════════════════════════════ */

function initSearch() {
  const searchInput       = document.getElementById("searchInput")
  const searchAutocomplete = document.getElementById("searchAutocomplete")
  if (!searchInput || !searchAutocomplete) return

  let searchTimer

  searchInput.addEventListener("input", () => {
    const query = searchInput.value
    clearTimeout(searchTimer)
    if (!query.trim()) {
      searchAutocomplete.classList.remove("active")
      return
    }
    searchTimer = setTimeout(() => fetchSearchResults(query), 200)
  })

  searchInput.addEventListener("focus", () => {
    if (searchInput.value.trim() && searchAutocomplete.querySelector(".search-autocomplete-item")) {
      searchAutocomplete.classList.add("active")
    }
  })

  document.addEventListener("click", (e) => {
    if (!searchInput.contains(e.target) && !searchAutocomplete.contains(e.target)) {
      searchAutocomplete.classList.remove("active")
    }
  })

  async function fetchSearchResults(query) {
    try {
      const res     = await fetch(`/api/search?q=${encodeURIComponent(query)}`)
      const results = await res.json()
      renderSearchResults(results)
    } catch (err) {
      console.error("Search error:", err)
      searchAutocomplete.innerHTML = '<div class="search-autocomplete-empty">Error searching</div>'
    }
  }

  function renderSearchResults({ projects = [], users = [] }) {
    if (projects.length === 0 && users.length === 0) {
      searchAutocomplete.innerHTML = '<div class="search-autocomplete-section"><div class="search-autocomplete-empty">No results found</div></div>'
      searchAutocomplete.classList.add("active")
      return
    }

    const projectIcon = '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" opacity="0.4"><rect width="4" height="4" x="3" y="3" rx="1"/></svg>'
    const userIcon    = '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" opacity="0.4"><circle cx="12" cy="8" r="4"/><path d="M 4 20 c 0 -4 3.6 -8 8 -8 s 8 4 8 8"/></svg>'

    let html = ""

    if (projects.length > 0) {
      html += '<div class="search-autocomplete-section">'
      html += '<div class="search-autocomplete-section-title">Projects</div>'
      html += projects.map(p => `
        <div class="search-autocomplete-item" onclick="selectSearchProject('${p.id}')">
          <div class="search-autocomplete-item-icon">
            ${p.avatar_url?.trim() ? `<img src="${p.avatar_url}" alt="" />` : projectIcon}
          </div>
          <div class="search-autocomplete-item-content">
            <div class="search-autocomplete-item-title">${p.title || p.name || "Untitled"}</div>
            <div class="search-autocomplete-item-meta">${p.display_name || "general"}</div>
          </div>
        </div>`).join("")
      html += "</div>"
    }

    if (users.length > 0) {
      html += '<div class="search-autocomplete-section">'
      html += '<div class="search-autocomplete-section-title">Users</div>'
      html += users.map(u => `
        <div class="search-autocomplete-item" onclick="selectSearchUser('${u.id}')">
          <div class="search-autocomplete-item-icon">
            ${u.avatar_url?.trim() ? `<img src="${u.avatar_url}" alt="" />` : userIcon}
          </div>
          <div class="search-autocomplete-item-content">
            <div class="search-autocomplete-item-title">${u.display_name || "User"}</div>
            <div class="search-autocomplete-item-meta">${u.total_hours || 0} hours</div>
          </div>
        </div>`).join("")
      html += "</div>"
    }

    searchAutocomplete.innerHTML = html
    searchAutocomplete.classList.add("active")
  }

  window.selectSearchProject = (id) => {
    searchInput.value = ""
    searchAutocomplete.classList.remove("active")
    viewProject(id)
  }
  window.selectSearchUser = (id) => {
    searchInput.value = ""
    searchAutocomplete.classList.remove("active")
    viewUser(id)
  }
}

/* ══════════════════════════════════════════════════════════
   HOME PAGE
   ══════════════════════════════════════════════════════════ */

function initHomePage() {
  // ── Carousel ──
  let currentSlide = 0
  const track         = document.getElementById("bannerTrack")
  const dotsContainer = document.getElementById("bannerDots")
  const slides        = track ? track.querySelectorAll(".banner-slide") : []
  const totalSlides   = slides.length

  if (totalSlides > 0) {
    for (let i = 0; i < totalSlides; i++) {
      const dot = document.createElement("div")
      dot.className = "banner-dot" + (i === 0 ? " active" : "")
      dot.setAttribute("data-index", i)
      dot.onclick = () => goToSlide(i)
      dotsContainer.appendChild(dot)
    }
  }

  function updateDots() {
    document.querySelectorAll(".banner-dot").forEach((d, i) =>
      d.classList.toggle("active", i === currentSlide))
  }

  window.goToSlide = function(n) {
    if (totalSlides === 0) return
    currentSlide = ((n % totalSlides) + totalSlides) % totalSlides
    track.style.transform = `translateX(-${currentSlide * 100}%)`
    updateDots()
  }

  window.slideCarousel = (dir) => goToSlide(currentSlide + dir)

  const wrapper = track?.closest(".banner-track-wrapper")
  let autoplay = setInterval(() => slideCarousel(1), 6000)
  wrapper?.addEventListener("mouseenter", () => clearInterval(autoplay))
  wrapper?.addEventListener("mouseleave", () => { autoplay = setInterval(() => slideCarousel(1), 6000) })

  // ── Nav pill active state ──
  document.querySelectorAll(".nav-pill").forEach(pill => {
    pill.addEventListener("click", () => {
      document.querySelectorAll(".nav-pill").forEach(p => p.classList.remove("active"))
      pill.classList.add("active")
    })
  })

  window.filterSection = (key) => console.log("filterSection:", key)

  // ── Render helpers ──
  window.renderBannerSlides = function(projects) {
    if (!projects?.length) return
    track.innerHTML = projects.map(p => `
      <div class="banner-slide" data-project-id="${p.id}">
        <div class="banner-image-area">
          ${p.banner_url?.trim() ? `<img src="${p.banner_url}" alt="${p.title || "Project"}" style="width:100%;height:100%;object-fit:cover;" loading="eager" onerror="this.style.display='none'" />` : ""}
          <div class="banner-image-placeholder ${p.banner_url?.trim() ? "hidden" : ""}">PROJECT IMAGE</div>
        </div>
        <div class="banner-info">
          <span class="banner-project-id">#${p.slack_channel || "general"}</span>
          <h2 class="banner-project-name">${p.title || p.name || "Untitled"}</h2>
          <div class="banner-slack-row">
            <div class="banner-slack-icon">
              ${p.avatar_url ? `<img src="${p.avatar_url}" alt="" />` : '<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" opacity="0.4"><rect width="4" height="4" x="3" y="3" rx="1"/></svg>'}
            </div>
            <span class="banner-slack-name">${p.display_name || "general"}</span>
          </div>
          <div class="banner-stats">
            <div class="banner-stat"><span class="banner-stat-val">—</span><span class="banner-stat-lbl">Rating</span></div>
            <div class="banner-stat"><span class="banner-stat-val">${p.total_hours || "—"}</span><span class="banner-stat-lbl">Hrs Spent</span></div>
            <div class="banner-stat"><span class="banner-stat-val">—</span><span class="banner-stat-lbl">Contributors</span></div>
          </div>
          <button class="banner-btn" onclick="viewProject('${p.id}')">
            View Project
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
          </button>
        </div>
      </div>`).join("")

    dotsContainer.innerHTML = projects.map((_, i) =>
      `<div class="banner-dot${i === 0 ? " active" : ""}" onclick="goToSlide(${i})"></div>`).join("")

    goToSlide(0)
  }

  window.renderProjectCards = function(container, projects) {
    if (!projects?.length) { container.innerHTML = '<p style="color:var(--muted)">No projects found</p>'; return }
    container.innerHTML = projects.map((p, i) => `
      <div class="project-card" onclick="viewProject('${p.id}')" data-project-id="${p.id}">
        <div class="project-card-thumb">
          ${p.banner_url?.trim() ? `<img src="${p.banner_url}" alt="${p.title || "Project"}" style="width:100%;height:100%;object-fit:cover;" loading="lazy" onerror="this.style.display='none'" />` : ""}
          <div class="thumb-placeholder ${p.banner_url?.trim() ? "hidden" : ""}">THUMBNAIL</div>
        </div>
        <span class="project-card-rank">${i + 1}</span>
        <div class="project-card-body">
          <div class="project-card-slack">
            <div class="project-card-icon">
              ${p.avatar_url ? `<img src="${p.avatar_url}" alt="" style="width:100%;height:100%;object-fit:cover;border-radius:4px;" loading="lazy" />` : '<svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><rect width="4" height="4" x="3" y="3" rx="1"/><rect width="4" height="4" x="17" y="3" rx="1"/><rect width="4" height="4" x="3" y="17" rx="1"/><rect width="4" height="4" x="17" y="17" rx="1"/></svg>'}
            </div>
            <span class="project-card-name">${p.title || p.name || "Untitled"}</span>
          </div>
          <span class="project-card-meta">${p.display_name || "general"} · ★ ${p.rank || "—"}</span>
        </div>
      </div>`).join("")
  }

  window.renderHCards = function(container, projects) {
    if (!projects?.length) { container.innerHTML = '<p style="color:var(--muted)">No projects found</p>'; return }
    container.innerHTML = projects.map(p => `
      <div class="hcard" onclick="viewProject('${p.id}')" data-project-id="${p.id}">
        <div class="hcard-thumb">
          ${p.banner_url?.trim() ? `<img src="${p.banner_url}" alt="${p.title || "Project"}" style="width:100%;height:100%;object-fit:cover;" loading="lazy" onerror="this.style.display='none'" />` : ""}
          <div class="thumb-placeholder ${p.banner_url?.trim() ? "hidden" : ""}">THUMBNAIL</div>
        </div>
        <div class="hcard-body">
          <div class="hcard-icon">
            ${p.avatar_url ? `<img src="${p.avatar_url}" alt="" style="width:100%;height:100%;object-fit:cover;border-radius:4px;" loading="lazy" />` : '<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><rect width="4" height="4" x="3" y="3" rx="1"/></svg>'}
          </div>
          <div>
            <div class="hcard-name">${p.title || p.name || "Untitled"}</div>
            <div class="hcard-sub">${p.display_name || "general"}</div>
          </div>
        </div>
      </div>`).join("")
  }

  window.renderBubbles = function(container, users) {
    if (!users?.length) { container.innerHTML = '<p style="color:var(--muted)">No contributors found</p>'; return }
    container.innerHTML = users.map(u => `
      <div class="bubble-item" data-user-id="${u.id}" onclick="viewUser('${u.id}')">
        <div class="bubble-avatar">
          <img src="${u.avatar_url}" alt="${u.name || u.display_name}" />
        </div>
        <div class="bubble-label">
          <div class="bubble-name">${u.name || u.display_name}</div>
          <div class="bubble-hours">${u.total_hours || 0}h</div>
        </div>
      </div>`).join("")
  }

  // ── Data loaders ──
  async function load(url) {
    const res  = await fetch(url)
    const data = await res.json()
    return Array.isArray(data) ? data : Object.entries(data).map(([id, item]) => ({id, ...item}))
  }

  async function loadFeaturedBanner()   { renderBannerSlides(await load("/api/hot")) }
  async function loadTopWeek()          { renderProjectCards(document.getElementById("topWeekGrid"),   await load("/api/top_this_week")) }
  async function loadFanFavourites()    { renderHCards(document.getElementById("fanFavGrid"),          await load("/api/fan_favourites")) }
  async function loadTopAllTime()       { renderHCards(document.getElementById("topAllTimeGrid"),      await load("/api/top_all_time")) }
  async function loadTopContributors()  { renderBubbles(document.getElementById("bubbleRow"),          Object.values(await (await fetch("/api/most_time_spent")).json())) }

  document.getElementById("footerYear").textContent = new Date().getFullYear()
  loadFeaturedBanner()
  loadTopWeek()
  loadFanFavourites()
  loadTopAllTime()
  loadTopContributors()
}

/* ══════════════════════════════════════════════════════════
   PROJECTS PAGE
   ══════════════════════════════════════════════════════════ */

function initProjectsPage() {
  let currentFilter  = "random"
  let allProjects    = []
  let displayedCount = 0
  const itemsPerLoad = 50
  let isLoadingMore  = false

  async function loadProjects() {
    try {
      const res      = await fetch(`/api/random_projects?filter=${currentFilter}`)
      allProjects    = await res.json()
      displayedCount = 0
      renderBatch()
      const countEl = document.getElementById("projectCount")
      countEl.textContent = allProjects.length > 0 ? `— ${allProjects.length} projects` : "— No projects"
    } catch (err) {
      console.error("Failed to load projects:", err)
      showEmpty()
    }
  }

  function renderBatch() {
    const grid        = document.getElementById("projectsGrid")
    const end         = Math.min(displayedCount + itemsPerLoad, allProjects.length)
    const batch       = allProjects.slice(displayedCount, end)

    if (batch.length === 0) { if (displayedCount === 0) showEmpty(); return }
    hideEmpty()
    if (displayedCount === 0) grid.innerHTML = ""

    batch.forEach((p, idx) => {
      const card    = document.createElement("div")
      card.className = "project-card"
      card.onclick   = () => viewProject(p.id)
      card.setAttribute("data-project-id", p.id)
      const rank    = displayedCount + idx + 1
      const hasImg  = p.banner_url?.trim()
      const hasAva  = p.avatar_url?.trim()
      card.innerHTML = `
        <div class="project-card-thumb">
          ${hasImg ? `<img src="${p.banner_url}" alt="${p.title || "Project"}" loading="lazy" onerror="this.style.display='none'" />` : ""}
          <div class="thumb-placeholder ${hasImg ? "hidden" : ""}">NO IMAGE</div>
          <span class="project-card-rank">${rank}</span>
        </div>
        <div class="project-card-body">
          <div class="project-card-slack">
            <div class="project-card-icon">
              ${hasAva ? `<img src="${p.avatar_url}" alt="" />` : '<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><rect width="4" height="4" x="3" y="3" rx="1"/></svg>'}
            </div>
            <div>
              <div class="project-card-name">${p.title || "Untitled"}</div>
              <div class="project-card-meta">${p.display_name || "Unknown"}</div>
            </div>
          </div>
          <div class="project-card-stats">❤️ ${p.likes || 0} · 🔥 ${Math.round(p.hot_score || 0)} · ⏱️ ${p.total_hours || 0}h</div>
        </div>`
      grid.appendChild(card)
    })

    displayedCount = end
    isLoadingMore  = false
  }

  function showEmpty() {
    document.getElementById("projectsGrid").style.display = "none"
    document.getElementById("emptyState").style.display  = "block"
  }
  function hideEmpty() {
    document.getElementById("projectsGrid").style.display = "grid"
    document.getElementById("emptyState").style.display  = "none"
  }

  // Infinite scroll
  const main = document.querySelector("main")
  main?.addEventListener("scroll", () => {
    const { scrollTop, scrollHeight, clientHeight } = main
    if (scrollHeight - (scrollTop + clientHeight) < 400 && !isLoadingMore && displayedCount < allProjects.length) {
      isLoadingMore = true
      renderBatch()
    }
  })

  window.shuffleProjects = () => {
    currentFilter = "random"
    document.getElementById("filterSelect").value = "random"
    loadProjects()
  }
  window.applyFilter = (filter) => { currentFilter = filter; loadProjects() }

  loadProjects()
}

/* ══════════════════════════════════════════════════════════
   PROJECT DETAIL PAGE
   ══════════════════════════════════════════════════════════ */

function initProjectPage(projectId) {
  function fmtDuration(seconds) {
    if (!seconds) return "—"
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    if (h > 0) return m > 0 ? `${h}h ${m}m` : `${h}h`
    return `${m}m`
  }

  function fmtDate(iso) {
    if (!iso) return "—"
    return new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })
  }

  function renderHero(raw) {
    if (!raw) return
    const project   = Array.isArray(raw) ? raw[0] : raw
    if (!project) return

    const placeholder = document.getElementById("heroPlaceholder")
    const imageArea   = document.getElementById("heroBannerImageArea")
    if (project.banner_url) {
      const img     = document.createElement("img")
      img.src       = project.banner_url
      img.alt       = project.title || "Project"
      img.className = "hero-img"
      img.onload    = () => { placeholder.style.display = "none"; img.classList.add("loaded") }
      img.onerror   = () => { placeholder.style.display = "flex" }
      imageArea.querySelector(".hero-img")?.remove()
      imageArea.appendChild(img)
    } else {
      placeholder.style.display = "flex"
    }

    document.getElementById("heroChannel").textContent = project.ship_status ? `#${project.ship_status}` : ""
    document.getElementById("heroTitle").textContent   = project.title || "Untitled Project"
    document.title = `${project.title || "Project"} — FTPDB`

    const authorEl = document.getElementById("heroAuthorRow")
    if (project.display_name || project.avatar_url) {
      const avatarHtml = project.avatar_url
        ? `<img class="hero-avatar" src="${escapeHtml(project.avatar_url)}" alt="" />`
        : `<div style="width:36px;height:36px;border-radius:50%;background:var(--surface2);flex-shrink:0"></div>`
      const name    = escapeHtml(project.display_name || "")
      const nameEl  = project.user_id
        ? `<a href="/user/${project.user_id}" class="hero-author-name" style="color:inherit;transition:color var(--transition)" onmouseover="this.style.color='var(--gold)'" onmouseout="this.style.color='inherit'">${name}</a>`
        : `<span class="hero-author-name">${name}</span>`
      authorEl.innerHTML = `${avatarHtml}${nameEl}`
    }

    document.getElementById("statHours").textContent = project.total_hours != null ? `${project.total_hours}` : "—"
    document.getElementById("statLikes").textContent = project.total_likes  != null ? `${project.total_likes}`  : "—"

    const ctaEl = document.getElementById("heroCta")
    ctaEl.href  = `https://flavortown.hackclub.com/projects/${projectId}`
    ctaEl.style.display = "inline-flex"

    const githubEl = document.getElementById("heroGithub")
    if (project.repo_url) { githubEl.href = escapeHtml(project.repo_url); githubEl.style.display = "inline-flex" }

    const demoEl = document.getElementById("heroDemo")
    if (project.demo_url) { demoEl.href = escapeHtml(project.demo_url); demoEl.style.display = "inline-flex" }
  }

  window.heroSlideCarousel = (_dir) => {} // single-project view — no-op

  function renderDevlogs(devlogs) {
    const timeline = document.getElementById("timeline")
    const countEl  = document.getElementById("devlogCount")
    const statEl   = document.getElementById("statDevlogs")

    countEl.textContent = `${devlogs.length} entr${devlogs.length === 1 ? "y" : "ies"}`
    statEl.textContent  = devlogs.length

    if (devlogs.length === 0) { timeline.innerHTML = `<div class="state-box">No devlogs yet.</div>`; return }

    timeline.innerHTML = devlogs.map((log, i) => {
      const hasScreenshot = log.attachments?.length > 0 && log.attachments[0]
      const body  = escapeHtml(log.body || "No content.")
      const long  = body.length > 400
      return `
        <div class="devlog-entry" style="animation-delay:${(i * 0.06).toFixed(2)}s" id="entry-${i}">
          <div class="devlog-card">
            ${hasScreenshot ? `<img class="devlog-screenshot" src="${escapeHtml(log.attachments[0])}" alt="Devlog screenshot" loading="lazy" onerror="this.remove()" />` : ""}
            <div class="devlog-body">
              <p class="devlog-text${long ? " clamped" : ""}" id="devlog-text-${i}">${body}</p>
              ${long ? `<button class="devlog-expand-btn" onclick="toggleExpand(${i})">Read more ↓</button>` : ""}
            </div>
            <div class="devlog-footer">
              <span class="devlog-meta-time">${fmtDate(log.created_at)}</span>
              ${log.duration_seconds ? `<span class="devlog-pill"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>${fmtDuration(log.duration_seconds)}</span>` : ""}
              <span class="devlog-pill"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>${log.likes_count || 0}</span>
              <span class="devlog-pill"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>${log.comments_count || 0}</span>
            </div>
          </div>
        </div>`
    }).join("")
  }

  window.toggleExpand = (i) => {
    const el  = document.getElementById(`devlog-text-${i}`)
    const btn = el.nextElementSibling
    const expanded = !el.classList.contains("clamped")
    el.classList.toggle("clamped", expanded)
    btn.textContent = expanded ? "Read more ↓" : "Show less ↑"
  }

  document.getElementById("footerYear").textContent = new Date().getFullYear()

  fetch(`/api/project_info/${projectId}`).then(r => r.json()).then(renderHero).catch(console.warn)
  fetch(`/api/devlogs/${projectId}`).then(r => r.json()).then(data => {
    renderDevlogs(Array.isArray(data) ? data : Object.values(data))
  }).catch(() => {
    document.getElementById("timeline").innerHTML = `<div class="state-box">Failed to load devlogs.</div>`
    document.getElementById("devlogCount").textContent = "Error"
  })
}

/* ══════════════════════════════════════════════════════════
   USER PAGE
   ══════════════════════════════════════════════════════════ */

function initUserPage(userId) {
  async function loadUserData() {
    try {
      const user = await (await fetch(`/api/user_info/${userId}`)).json()
      const headerEl = document.getElementById("userHeader")
      headerEl.innerHTML = `
        <div>
          ${user.avatar_url?.trim()
            ? `<img class="user-avatar" src="${escapeHtml(user.avatar_url)}" alt="${escapeHtml(user.display_name || "User")}" />`
            : `<div class="user-avatar skeleton"></div>`}
        </div>
        <div class="user-info">
          <h1 class="user-name">${escapeHtml(user.display_name || "User")}</h1>
          <div class="user-stats">
            <div class="user-stat">
              <span class="user-stat-val">${user.total_hours || 0}</span>
              <span class="user-stat-lbl">Hours</span>
            </div>
          </div>
        </div>`
    } catch (e) { console.error("Failed to load user data:", e) }
  }

  async function loadProjects() {
    try {
      const projects = await (await fetch(`/api/user_projects/${userId}`)).json()
      const grid     = document.getElementById("projectsGrid")
      const countEl  = document.getElementById("projectCount")

      if (!projects?.length) {
        document.getElementById("emptyState").style.display = "block"
        grid.style.display = "none"
        countEl.textContent = ""
        return
      }

      countEl.textContent = `— ${projects.length}`
      grid.innerHTML = projects.map(project => {
        const title   = escapeHtml(project.title || "Untitled")
        const hasImg  = project.banner_url?.trim()
        return `
          <div class="project-card" onclick="viewProject('${project.id}')">
            <div class="project-card-thumb">
              ${hasImg ? `<img src="${project.banner_url}" alt="${title}" loading="lazy" onerror="this.style.display='none';this.nextElementSibling.classList.remove('hidden')" />` : ""}
              <div class="thumb-placeholder ${hasImg ? "hidden" : ""}">NO IMAGE</div>
            </div>
            <div class="project-card-body">
              <div class="project-card-title">${title}</div>
              <div class="project-card-stats">❤️ ${project.total_likes || 0} · ⏱️ ${project.total_hours || 0}h</div>
            </div>
          </div>`
      }).join("")
    } catch (e) {
      console.error("Failed to load projects:", e)
      document.getElementById("emptyState").style.display = "block"
    }
  }

  loadUserData()
  loadProjects()
}

/* ══════════════════════════════════════════════════════════
   SUGGESTIONS PAGE
   ══════════════════════════════════════════════════════════ */

function initSuggestionsPage() {
  document.getElementById("footerYear").textContent = new Date().getFullYear()

  const form          = document.getElementById("suggestionsForm")
  const alertContainer = document.getElementById("alertContainer")
  const submitBtn     = document.getElementById("submitBtn")

  function showAlert(type, message) {
    const icon = type === "success"
      ? '<polyline points="20 6 9 17 4 12"></polyline>'
      : '<circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line>'
    alertContainer.innerHTML = `
      <div class="alert alert-${type}">
        <svg class="alert-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">${icon}</svg>
        <div>${message}</div>
      </div>`
  }

  form.addEventListener("submit", async (e) => {
    e.preventDefault()
    submitBtn.disabled    = true
    const originalHTML    = submitBtn.innerHTML
    submitBtn.textContent = "Submitting..."

    try {
      const res = await fetch("/api/suggest", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          display_name: document.getElementById("displayName").value,
          category:     document.getElementById("category").value,
          title:        document.getElementById("title").value,
          message:      document.getElementById("message").value,
        }),
      })

      if (res.ok) {
        showAlert("success", "Thank you! Your suggestion has been received.")
        form.reset()
      } else {
        const error = await res.json()
        showAlert("error", error.message || "Failed to submit. Please try again.")
      }
    } catch (err) {
      console.error("Error:", err)
      showAlert("error", "An error occurred. Please try again later.")
    } finally {
      submitBtn.disabled  = false
      submitBtn.innerHTML = originalHTML
    }
  })
}

/* ══════════════════════════════════════════════════════════
   BOOTSTRAP — detect page & initialise
   ══════════════════════════════════════════════════════════ */

document.addEventListener("DOMContentLoaded", () => {
  initSearch()

  if (document.getElementById("bannerTrack"))   initHomePage()
  if (document.getElementById("projectsGrid") && document.getElementById("filterSelect")) initProjectsPage()

  const projectEl = document.getElementById("ftpdb-project-id")
  if (projectEl) initProjectPage(projectEl.dataset.id)

  const userEl = document.getElementById("ftpdb-user-id")
  if (userEl) initUserPage(userEl.dataset.id)

  if (document.getElementById("suggestionsForm")) initSuggestionsPage()
})



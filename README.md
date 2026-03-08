
# FTPDB

  

## An IMDB like website for Projects, Users & Devlogs on the flavortown website

## API Documentation
- https://registry.scalar.com/@jam06452/apis/ftpdb-public-api@latest

## Features
- Liveish stats, refresh every six hours through a containered scraper
- The ability to search for Projects & Users at the sametime
- User Profiles with other projects & Time Spents
- Project Profiles with all avaliable Devlogs with markdown rendering to support images
- Suggestions page  that sends suggestions to my slack via a slack bot

## Tech Stack
- Elixir & Phoenix Liveview
- Supabase as the database
- Python for the scraper

## Optimizations
- Application caching on the elixir server via cachex
- Page caching via cloudflare

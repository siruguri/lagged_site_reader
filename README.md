# Writing Buddy: Community of writers reading each other

## Starting The Server

Run `bin/dev` - this uses `Procfile.dev`

## Quick start

You need **Ruby 3.2+** on your Mac. Then:

```sh
cd everything_app
./setup_rails_app.sh
```

The setup script (some of this relates to the site scraper idea described in docs/site-scraper.md, can be cleaned up later):

1. installs `bundler` and `rails ~> 8.0` if missing,
2. runs `rails new .` with sensible flags (sqlite3, no test/jbuilder/cable/
   action-text/active-storage/solid, no kamal/docker — it's a personal tool),
3. preserves the crawler classes already in this folder,
4. appends `nokogiri`, `sidekiq`, `redis`, `sidekiq-scheduler` to the Gemfile,
5. runs `bundle install` and `bin/rails db:prepare`,
6. drops in the Sidekiq job + `config/sidekiq.yml` schedule.

## Dev Ops information

Some of the details of the setup I did are in deploy.md

* Machine on Digital Ocean: ssh -i ~/.ssh/digital_ocean root@143.244.176.203
* The web server is Caddy (not nginx or Apache.)
# The app is deployed under /srv and belongs to the user "deploy"
* There is a Go daemon that listens at /deploy where it receives a POST when there is a commit to main
  * This runs deploy.sh which handles the git fetch; and the docker commands.

This is important - see the part in deploy.md where it says how to set the master key in .env. .env is not checked into
the repo; .env.example is, and it has to be copied to .env during initial setup.

## Authentication

Accounts are backed by Devise (`Account` model, email as the unique key).

- Sign up: `/accounts/sign_up`
- Log in: `/accounts/sign_in`

## Main Project

### Dependencies

**CSS**

Uses TailwindCSS

**Javascript**

* cropper.js for profile pic manipulation


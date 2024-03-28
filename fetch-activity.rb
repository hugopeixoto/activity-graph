#!/usr/bin/env ruby

# SPDX-FileCopyrightText: 2024 Hugo Peixoto <hugo.peixoto@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-only

require 'net/http'
require 'json'
require 'date'

config = JSON.parse(File.read("config.json"))

def github_activity(username, token)
  query = "query {
    user(login: \"#{username}\") {
      contributionsCollection {
        contributionCalendar {
          weeks {
            contributionDays {
              date
              contributionCount
            }
          }
        }
      }
    }
  }"

  URI("https://api.github.com/graphql")
    .then { Net::HTTP.post(_1, JSON.dump({ query: }), { "Authorization" => "bearer #{token}" }) }
    .then(&:body)
    .then { JSON.parse(_1) }
    .dig("data", "user", "contributionsCollection", "contributionCalendar", "weeks")
    .flat_map { |w| w["contributionDays"] }
    .map { |d| [d["date"], d["contributionCount"]] }
    .to_h
end

def gitlab_activity(username)
  URI("https://gitlab.com/users/#{username}/calendar.json")
    .then { Net::HTTP.get(_1) }
    .then { JSON.parse(_1) }
end

def gitea_activity(username, url, token)
  headers =
    if token
      { "Authorization" => "bearer #{token}" }
    else
      {}
    end

  URI("https://#{url}/api/v1/users/#{username}/heatmap")
    .then { Net::HTTP.get(_1, headers) }
    .then { JSON.parse(_1) }
    .map { |x| [Time.at(x["timestamp"]).to_date.to_s, x["contributions"]] }
    .group_by { |x| x[0] }
    .transform_values { |v| v.map(&:last).sum }
end

def activity(forge)
  case forge["url"]
  when "github.com"
    github_activity(forge["username"], forge["token"])
  when "gitlab.com"
    gitlab_activity(forge["username"])
  else
    gitea_activity(forge["username"], forge["url"], forge["token"])
  end

end

config["forges"]
  .map { |forge| { url: forge["url"], activity: activity(forge) } }
  .then { JSON.dump(_1) }
  .then { File.write("activity.json", _1) }

#!/usr/bin/env ruby

# SPDX-FileCopyrightText: 2024 Hugo Peixoto <hugo.peixoto@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-only

require 'net/http'
require 'json'
require 'date'

config = JSON.parse(File.read("config.json"))

username = ARGV.fetch(0)

def github_activity(username, token)
  query = "query {
    user(login: \"#{username}\") {
      contributionsCollection {
        contributionCalendar {
          weeks {
            contributionDays {
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

def ansol_activity(username, token)
  URI("https://git.ansol.org/api/v1/users/#{username}/heatmap")
    .then { Net::HTTP.get(_1, { "Authorization" => "bearer #{token}" }) }
    .then { JSON.parse(_1) }
    .map { |x| [Time.at(x["timestamp"]).to_date.to_s, x["contributions"]] }
    .group_by { |x| x[0] }
    .transform_values { |v| v.map(&:last).sum }
end

def gitlab_activity(username)
  URI("https://gitlab.com/users/#{username}/calendar.json")
    .then { Net::HTTP.get(_1) }
    .then { JSON.parse(_1) }
end

{
  github: github_activity(username, config.dig("tokens", "github")),
  ansol: ansol_activity(username, config.dig("tokens", "ansol")),
  gitlab: gitlab_activity(username),
}
  .then { JSON.dump(_1) }
  .then { File.write("activity.json", _1) }

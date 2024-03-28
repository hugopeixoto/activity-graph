#!/usr/bin/env ruby

# SPDX-FileCopyrightText: 2024 Hugo Peixoto <hugo.peixoto@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-only

require 'json'
require 'date'

activity = File
  .read("activity.json")
  .then { JSON.parse(_1) }

finish = Date.parse(activity.map { |f| f["activity"] }.flat_map(&:keys).max)
start = finish.prev_year
while not start.sunday?
  start = start.prev_day
end

def bucket(contribs)
  if contribs == 0
    0
  elsif contribs < 10
    1
  elsif contribs < 20
    2
  elsif contribs < 30
    3
  else
    4
  end
end

output = File.open("activity.html", "w+")

output.puts <<EOF
<html>
  <style>
    .calendar {
      display: flex;
      flex-direction: column;
      flex-wrap: wrap;
      height: calc(10px * 7 + 3px * 6);
      width: calc(10px * 53 + 3px * 52);
      gap: 3px;
      align-content: start;
    }
    .day {
      width: 10px;
      height: 10px;
    }
    .bucket0 { background-color: #ececef; }
    .bucket1 { background-color: #d2dcff; }
    .bucket2 { background-color: #7992f5; }
    .bucket3 { background-color: #3f51ae; }
    .bucket4 { background-color: #2a2b59; }
    h2 { font-family: monospace; text-align: center; }
    body {
      padding-top: 20px;
      margin: 0px auto;
      width: calc(10px * 53 + 3px * 52);
    }
  </style>

  <body>
EOF

def graph(label, range, &fn)
  s = ""
  s << "<h2>#{label}</h2>\n"
  s << "<div class='calendar'>\n"
  range.each do |day|
    s << "<div class='day bucket#{bucket(fn[day])}'></div>"
  end
  s << "\n</div>\n"
  s
end

output << graph("activity", start..finish) do |day|
  activity.map { |f| f["activity"].fetch(day.to_s, 0) }.sum
end

activity.each do |forge|
  output << graph(forge["url"], start..finish) do |day|
    forge["activity"].fetch(day.to_s, 0)
  end
end

output.puts <<EOF
  </body>
</html>
EOF

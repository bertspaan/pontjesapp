#!/usr/local/bin/ruby

require 'json'

dbconf = JSON.parse(File.read('../config.json'))['postgres']

database = "postgres://#{dbconf['user']}:#{dbconf['password']}@#{dbconf['host']}/#{dbconf['database']}"
command = "sequel -m migrations #{database}"

system command
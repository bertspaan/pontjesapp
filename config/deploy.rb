#set :stages, %w(production testing opt)
#set :default_stage, "testing"

server 'http://sandbox3.loosecontrol.tv/', :app, :web, :primary => true

require 'capistrano/ext/multistage'
# require "bundler/capistrano"

set :application, "pontjesapp"
# set :repository,  "gits:citysdk"
# 
# set :scm, :git

set :repository,  "."
set :scm, :none

set :branch, "master"

set :deploy_to, "/home/bert/pontjesapp"
#set :deploy_to, "/var/www/pontjesapp"
# set :deploy_via, :remote_cache

#set :copy_exclude, ['database.json','tmp']

set :deploy_via, :copy

set :use_sudo, false
set :user, "bert"

default_run_options[:shell] = '/bin/bash'

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  # Assumes you are using Passenger
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end
 
  task :finalize_update, :except => { :no_release => true } do

    # run <<-CMD
    #   rm -rf #{latest_release}/log &&
    #   ln -s #{shared_path}/log #{latest_release}/log &&
    #   ln -s #{shared_path}/config/database.json #{release_path} &&
    #   mkdir -p #{latest_release}/tmp &&
    #   mkdir -p #{latest_release}/public
    # CMD
    
 
  end
end  



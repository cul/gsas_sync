# frozen_string_literal: true

# config valid for current version and patch releases of Capistrano
lock '~> 3.19.2'

set :application, 'gsas_sync'
set :repo_name, fetch(:application)
set :repo_url, "git@github.com:cul/#{fetch(:repo_name)}.git/"
set :deploy_name, -> { "#{fetch(:application)}_#{fetch(:stage)}" }
set :remote_user, 'ldpdserv' # because we are accessing preservation storage

ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# deploy_name = gsas_sync_{dev|test|prod}
set :deploy_to, -> { "/opt/scripts/#{fetch(:deploy_name)}" }

# Tag edits to the cron file - these will be overwritten each new deployment
set :whenever_identifier, -> { "#{fetch(:application)}_#{fetch(:stage)}" }
# Only servers with the production_app role will edit the crontab
set :whenever_roles, %w[production_app]
set :whenever_environment, -> { fetch(:stage) }
# Pass data to be used in schedule.rb
set :whenever_variables, -> { "'script_env=#{fetch(:deploy_name)}&rvm_command_prefix=#{fetch(:rvm_command_prefix)}'" }
# default whenever_command is ->{[]:bundle, :exec, :whenever]}
# This should be okay for gsas_sync
# set :whenever_command, lambda {
#   "whenever --set 'script_env=#{fetch(:deploy_name)}&path=#{deploy_to}/current/gsas_sync_main.rb&rvm_prefix=#{fetch(:rvm_command_prefix)}'" # rubocop:disable Layout/LineLength
# }

# Configure location where capistrano.log will be written
set :format_options, log_file: 'logs/capistrano.log'

append :linked_files, 'config/config.yml'

append :linked_dirs, '.bundle', 'logs'

# Until we retire all old CentOS VMs, we need to set the rvm_custom_path because rvm is installed
# in a non-standard location for our AlmaLinux VMs.  This is because our service accounts need to
# maintain two rvm installations for two different Linux OS versions.
set :rvm_custom_path, '~/.rvm-alma8' # default ~/.rvm
# RVM Setup, for selecting the correct ruby version (instead of capistrano-rvm gem)
set :rvm_ruby_alias, fetch(:deploy_name) # This RVM alias must exist on the server -- and make sure to use it
set :rvm_command_prefix, "#{fetch(:rvm_custom_path, '~/.rvm')}/bin/rvm #{fetch(:rvm_ruby_alias)} do"
[:rake, :gem, :bundle, :ruby, :whenever].each do |command_to_prefix|
  SSHKit.config.command_map.prefix[command_to_prefix].push(
    fetch(:rvm_command_prefix)
  )
end

# set :keep_releases, 5

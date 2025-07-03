# frozen_string_literal: true

# config valid for current version and patch releases of Capistrano
lock '~> 3.19.2'

# Until we retire all old CentOS VMs, we need to set the rvm_custom_path because rvm is installed
# in a non-standard location for our AlmaLinux VMs.  This is because our service accounts need to
# maintain two rvm installations for two different Linux OS versions.
set :rvm_custom_path, '~/.rvm-alma8' # default ~/.rvm

set :application, 'gsas_sync'
set :repo_name, fetch(:application)
set :repo_url, "git@github.com:cul/#{fetch(:repo_name)}.git/"
set :deploy_name, -> { "#{fetch(:application)}_#{fetch(:stage)}" }
set :remote_user, 'ldpdserv' # because we are accessing preservation storage (confirm this is appropriate)
# set :remote_user, 'ldpdserv' # because we are accessing preservation storage (confirm this is appropriate)

# Default branch is :master
set :branch, 'LDPD-451' # TODO: use main when actually deploying
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# TODO : change to /opt/scripts/ when it is time for real deploy =)
set :deploy_to, -> { "/tmp/gsas_deployment_testing/#{fetch(:deploy_name)}" } # Override this for each environment

set :whenever_identifier, -> { "#{fetch(:application)}_#{fetch(:stage)}" }

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", 'config/master.key'
append :linked_files, 'config/config.yml'

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "vendor", "storage"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

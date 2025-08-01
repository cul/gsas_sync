# frozen_string_literal: true

# THIS FILE IS STILL A WORK IN PROGRESS;
# GSAS SYNC'S DEPLOYMENT FLOW HAS NOT BEEN FINALIZED/TESTED

# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# Log cron output to app log directory
# set :output, ("shared/log/#{Rails.env}_cron_log.log")

# Our job template wraps the cron job in a script that emails out any unhandled errors.
# This is a CUL provided script. More details can be found here:
# https://wiki.library.columbia.edu/display/USGSERVICES/Cron+Management
set :email_subject, 'GSAS Sync Cron Error (via Whenever Gem)'
set :error_recipient, 'bg2918@columbia.edu' # Todo change to dev email from config or better to directly read the yml file
set :job_template, "/usr/local/bin/mailifrc -s 'Error - :email_subject' :error_recipient -- /bin/bash -l -c ':job'"

# Override default rake task job type
# job_type :rake, 'cd :path && :environment_variable=:environment bundle exec rake :task --silent :output'

every 1.minute do
  # commnad "cd #{@path} && ~/.rvm-alma8/bin/rvm ENV[script_env] do ruby testscript.rb"
  # command "echo 'test' > /tmp/test_cron.txt"
  # command "echo '#{@environment}\n #{@rvm_command_prefix}\n ' > /tmp/whenever_stuff.txt"
  command "#{@rvm_command_prefix} #{@path}/testscript.rb"
end

# every :month do
# command 'ruby /tmp/gsas_deployment_testing/gsas_sync_staging/current/gsas_sync_main.rb --log-level fatal'
# end

# frozen_string_literal: true

# THIS FILE IS STILL A WORK IN PROGRESS;
# GSAS SYNC'S DEPLOYMENT FLOW HAS NOT BEEN FINALIZED/TESTED

# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# Our job template wraps the cron job in a script that emails out any unhandled errors.
# This is a CUL provided script. More details can be found here:
# https://wiki.library.columbia.edu/display/USGSERVICES/Cron+Management
set :email_subject, 'GSAS Sync Cron Error (via Whenever Gem)'
set :error_recipient, 'bg2918@columbia.edu' # Todo change to dev email the config yml file
set :job_template, "/usr/local/bin/mailifrc -s 'Error - :email_subject' :error_recipient -- /bin/bash -l -c ':job'"
puts 'whenever.rb file:'
puts "@script_env#{@script_env}"

# Override default rake task job type
# job_type :rake, 'cd :path && :environment_variable=:environment bundle exec rake :task --silent :output'

############################  COMMAND  #########################################
# Run dissertation sync script once a day on days 1-7 of each month:
every '0 0 1-7 * *', at: '12:01 am' do
  command "echo 'script_env is : #{@script_env}' > /tmp/script_env.txt"
  unless @script_env == 'gsas_sync_prod' # rubocop:disable Style/IfUnlessModifier
    command "#{@rvm_command_prefix} #{@path}/gsas_sync_main.rb"
  end
end
################################################################################

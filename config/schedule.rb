# frozen_string_literal: true

# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# Log cron output to app log directory
# set :output, ("shared/log/#{Rails.env}_cron_log.log")

# Our job template wraps the cron job in a script that emails out any unhandled errors.
# This is a CUL provided script. More details can be found here:
# https://wiki.library.columbia.edu/display/USGSERVICES/Cron+Management
set :email_subject, 'GSAS Sync Cron Error (via Whenever Gem)'
set :error_recipient, '...' # Todo change to dev email from config or better to directly read the yml file
set :job_template, "/usr/local/bin/mailifrc -s 'Error - :email_subject' :error_recipient -- /bin/bash -l -c ':job'"

# Override default rake task job type
# job_type :rake, 'cd :path && :environment_variable=:environment bundle exec rake :task --silent :output'

every 1.minute do
  command 'date > /tmp/hello.txt'
end

every :month do
  command 'ruby gsas_sync_main.rb --log-level fatal'
end

every 1.minute do
  command 'ruby gsas_sync_main.rb'
end

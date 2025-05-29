#!/usr/bin/env ruby

# frozen_string_literal: true

# Require all gems in Gemfile
require 'bundler'
Bundler.require(:default)

# Auto-load all files in lib directory
loader = Zeitwerk::Loader.new
loader.push_dir('lib')
loader.setup # ready!

require 'pathname'
require 'optparse'

################################################################################
################################ SCRIPT ########################################
################################################################################

args = GsasSync::ArgParser.parse_cl_args
args => { log_lvl: log_lvl}

# TODO: There should be a better way to do this
GsasSync::Logger.stdout_log_level = log_lvl

gsas_sync = GsasSync.new

GsasSync::Logger.begin_step('Download files from remote',
                            "Downloading files from the remote transfer (sftp) server #{GsasSync::Config.sftp_server_str}")
gsas_sync.download_files_to_temp_dir

temp_dir_path = "#{Pathname.pwd}/#{GsasSync::TEMP_DIR}/"

GsasSync::Logger.begin_step('Validating downloaded files')
valid = gsas_sync.validate_downloaded_files(temp_dir_path)

unless valid
  GsasSync::Logger.log_all_fatal('One or more of the validation tests failed. The script will send a notificaiton email and exit.')
  gsas_sync.send_failure_email
  gsas_sync.graceful_exit
end

GsasSync::Logger.begin_step('Moving the downloaded files to the final destination on local server')
GsasSync::Logger.log_all('All downloaded files were validated. Sending successn notification.')

begin
  gsas_sync.move_temp_files
  gsas_sync.rm_remote_files
  gsas_sync.rm_temp_dir
rescue StandardError => e
  GsasSync::Logger.log_all_error(
    'An error occurred while trying to move the downloaded files or delete them from the remote transfer server. The script will terminate...', e
  )
  gsas_sync.graceful_exit
end

# Not for developers:
# When sending the success email, the progress log file handle will be closed in order to add it as an attachment.
# The following will close the file handle: GsasSync#send_success_email, GsasSync#send_failure_email
# Therefore, after this point, only the stdout logger is available.
GsasSync::Logger.begin_step('Sending Email Notifications', 'This is the final step')
begin
  gsas_sync.send_success_email
rescue StandardError => e
  begin
    GsasSync::Logger.log_all_error('', e)
    gsas_sync.send_failure_email
  rescue StandardError => e
    GsasSync::Logger.log_all_error('', e)
    gsas_sync.graceful_exit
  end
end

GsasSync::Logger.stdout_logger.info('The Gsas Sync Process has completed successfully.')
gsas_sync.graceful_exit

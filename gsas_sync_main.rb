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

GsasSync::Logger.begin_step('Validating downloaded files')
valid = gsas_sync.validate_downloaded_files

unless valid
  GsasSync::Logger.log_all_fatal('One or more of the validation tests failed. The script will send a notificaiton email and exit.')
  gsas_sync.email_and_exit_failure
end

GsasSync::Logger.begin_step('Moving the downloaded files to the final destination on local server')
begin
  gsas_sync.rename_temp_dirs
rescue StandardError => e
  GsasSync::Logger.log_all_error(
    'An error occurred while trying to move the downloaded files. The script will terminate...', e
  )
  gsas_sync.email_and_exit_failure
end

GsasSync::Logger.begin_step('Deleting the downloaded files on the remote SFTP server')
begin
  gsas_sync.rm_remote_files
rescue StandardError => e
  GsasSync::Logger.log_all_error(
    'An error occurred while trying to delete them from the remote transfer server. The script will terminate...', e
  )
  gsas_sync.email_and_exit_failure
end
# Not for developers:
# When sending the success email, the progress log file handle will be closed in order to add it as an attachment.
# The following will close the file handle: GsasSync#send_success_email, GsasSync#send_failure_email
# Therefore, after that point, only the stdout logger is available.
# You can reopen the file for appending with GsasSync::Logger::append (this will close the file again before returning)
GsasSync::Logger.begin_step('Sending Email Notifications', 'This is the final step')
GsasSync::Logger.progress('Summary of what was downloaded from the remote transfer server:')
# TODO: do this based on the gsas_sync objects @dissertation_dirs instance variable!
GsasSync::Logger.progress_log_dir_contents(GsasSync::Config.storage['directory'],
                                           'Successfully downloaded the following files:')
gsas_sync.email_and_exit_success

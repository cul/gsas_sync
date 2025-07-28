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
args => { log_lvl: _log_lvl, dry_run: _dry_run }

begin
  GsasSync::Config.validate_config
rescue StandardError => e
  GsasSync::Logger.stdout_logger.fatal "Could not load values from config file. Script will terminate. Error: #{e}"
  exit(1)
end

if GsasSync::Config.dry_run
  GsasSync::Logger.log_all 'Gsas Sync is running in dry run mode.'
  GsasSync::Logger.log_all('Files will be downloaded temporarily, validated, then deleted.'\
    ' No files will be permanently moved or deleted from either the local host or remote transfer server.'\
    ' No email notification will be sent.')
end

gsas_sync = GsasSync.new
server_name = GsasSync::Config.sftp_server_str

GsasSync::Logger.begin_step('Download files from remote',
                            "Downloading files from the remote transfer (sftp) server #{server_name}")
begin
  gsas_sync.download_files_to_temp_dir
rescue StandardError => e
  GsasSync::Logger.log_all_fatal("An error occurred downloading files from the remote server. Error: #{e}. Exiting...")
  gsas_sync.email_and_exit(success: false)
end

GsasSync::Logger.begin_step 'Validating downloaded files'
begin
  valid = gsas_sync.validate_downloaded_files
rescue StandardError => e
  GsasSync::Logger.log_all_fatal("An unexpected fatal error occurred while validating the downloaded files: #{e}. Unable to proceed. Exiting...") # rubocop:disable Layout/LineLength
  gsas_sync.email_and_exit(success: false)
end

unless valid
  GsasSync::Logger.log_all_fatal 'One or more validation tests failed. The process will send a failure email and exit.'
  gsas_sync.email_and_exit(success: false)
end

GsasSync::Logger.begin_step 'Moving the downloaded files to the final destination on local server'
begin
  gsas_sync.rename_temp_dirs
rescue StandardError => e
  GsasSync::Logger.log_all_error(
    'An error occurred moving the downloaded directory on the local server from temporary to preservation location.'\
    ' The script will terminate...', e
  )
  gsas_sync.email_and_exit(success: false)
end

GsasSync::Logger.begin_step 'Deleting the downloaded files on the remote SFTP server'
begin
  gsas_sync.rm_remote_files
rescue StandardError => e
  GsasSync::Logger.log_all_error(
    'An error occurred while trying to delete the transferred files on the remote transfer server.'\
    ' The script will terminate...', e
  )
  gsas_sync.email_and_exit(success: false)
end

GsasSync::Logger.begin_step 'Print Summary of the Transfer'
gsas_sync.log_summary

# Note for developers:
# When sending the success email, the progress log file handle will be closed in order to add it as an attachment.
# GsasSync#email_and_exit will close the file handle
# Therefore, after that point, only the stdout logger is available.
# You can reopen the file for appending with GsasSync::Logger::append (this will close the file again before returning)
GsasSync::Logger.begin_step 'Sending Email Notifications', 'This is the final step'
gsas_sync.email_and_exit(success: true)

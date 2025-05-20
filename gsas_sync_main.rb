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

args = ArgParser.parse_cl_args
args => { config_file: config_file, elog_file: elog_file, llog_lvl: llog_lvl}
# puts 'ARG VALUES:'
# p config_file
# p elog_file
# p llog_lvl
# puts '******************'
# # Set up error log file
# File.mkdir('logs') unless File.directory?('logs')
# File.delete('logs/elog.txt') if File.file?('logs/elog.txt')

# File.new('logs/error_log.txt', 'w')

gsas_sync = GsasSync.new(config_file, elog_file, llog_lvl)
gsas_sync.send_test_email

# gsas_sync.logger.debug 'debug message'
# gsas_sync.logger.info 'info'
# gsas_sync.logger.warn 'warning'
# gsas_sync.logger.error 'error'
# gsas_sync.logger.fatal 'fatal!'
# gsas_sync.logger.unknown 'unknown'

# p gsas_sync.config
puts 'valid path' if Cul::PreservationUtils::FilePath.valid_file_path?('a/b/c')

gsas_sync.download_files_to_temp_dir

temp_dir_path = "#{Pathname.pwd}/temp/"
unless gsas_sync.validate_downloaded_files(temp_dir_path)
  puts 'Send failure email'
  # TODO
end

puts 'DONE!'

# sftp_client = SftpClient.new(gsas_sync.config)
# sftp_client.connect

# sftp_client.ls('uploads')

# sftp_client.dl_recursive('uploads', 'temp')

# sftp_client.disconnect

# # Add any directories that match the yyyy_mm_dissertations/ pattern to an array
# # Validate each in turn
# temp_dir_path = "#{Pathname.pwd}/temp/"
# uploads_dir = Pathname.new(temp_dir_path)
# validators = []
# uploads_dir.children.each do |child|
#   if child.basename.to_s.match?(Validator::DISSERTATION_DIR_REGEX)
#     p "#{uploads_dir}#{child.basename}/"
#     validators.push(Validator.new("#{uploads_dir}#{child.basename}/"))
#   end
# end
# validators.each do |validator|
#   # TODO: do NOT lazy evaluate; we want to be able to list ALL of the validation errors so that ALL errors can be
#   # addressed by GSAS at once. Otherwise, there could be a situation where they address an issue, try to transfer again,
#   # and it fails again for a novel reason -- better if they can know all the errors at one time.
#   if validator.all_required_files_present? &&
#      validator.undesirable_characters_in_file_paths? &&
#      validator.all_accounted_for_in_manifest? &&
#      validator.valid_checksums?
#     puts 'pass!'
#   else
#     puts 'fail!'
#   end
# end

# Open an SFTP with the transfer server
# Download all of the files from the server to temp directory
# Validate the Files
# Move the files from the temp directory to the final destination
# Open an SFTP session and remove the files from the remote host
# send a success email
# -> if any of the above steps fail (before rm the files), abort the process and send an error email

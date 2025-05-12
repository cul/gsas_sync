#!/usr/bin/env ruby

# frozen_string_literal: true

# Require all gems in Gemfile
require 'bundler'
Bundler.require(:default)

# Auto-load all files in lib directory
loader = Zeitwerk::Loader.new
loader.push_dir('lib')
loader.setup # ready!

# Run code!
gsas_sync = GsasSync.new('config/config.yml')
# p gsas_sync.config
puts 'valid path' if Cul::PreservationUtils::FilePath.valid_file_path?('a/b/c')

sftp_client = SftpClient.new(gsas_sync.config)
sftp_client.connect

sftp_client.ls('uploads')

# sftp_client.dl_recursive('uploads', 'temp')

sftp_client.disconnect

# Open an SFTP with the transfer server
# Download all of the files from the server to temp directory
# Validate the Files
# Move the files from the temp directory to the final destination
# Open an SFTP session and remove the files from the remote host
# send a success email
# -> if any of the above steps fail (before rm the files), abort the process and send an error email

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
p gsas_sync.config
puts 'valid path' if puts Cul::PreservationUtils::FilePath.valid_file_path?('a/b/c')

sftp_client = SftpClient.new(gsas_sync.config)
sftp_client.connect

sftp_client.ls

sftp_client.disconnect

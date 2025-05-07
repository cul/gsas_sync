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
dissertation_mngr = GsasDissertationManager.new('config/config.yml')
puts 'valid path' if dissertation_mngr.valid_file_path?('a/b/c')

some_instance = ExampleClass.new
puts some_instance.example_instance_method

puts ExampleClass.example_class_method

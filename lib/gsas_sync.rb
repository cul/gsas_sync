# frozen_string_literal: true

require 'rainbow'

class GsasSync
  TERM_PREFIX = '[gsas_sync]'
  TEMP_DIR = 'temp'
  UPLOADS_DIR = 'uploads'

  attr_accessor :config, :logger

  def initialize(config_file, elog_file, llog_lvl)
    @config = load_config_file(config_file)
    @logger = Logger.new($stdout, llog_lvl, progname: 'gsas_sync')
    @elog = ErrorHandling.init(*File.split(elog_file), @logger)
    Logging.format_logger @logger
    @logger.debug 'Initialized GsasSync Object'
  end

  def download_files_to_temp_dir
    @logger.debug('GsasSync#download_files_to_temp_dir(): Entry')
    begin
      @sftp_client = SftpClient.new(@config, @logger)
      @sftp_client.connect
      @sftp_client.ls(UPLOADS_DIR)
      @sftp_client.dl_recursive(UPLOADS_DIR, TEMP_DIR)
      @sftp_client.disconnect
    rescue StandardError => e
      @logger.fatal("An error ocurred downloading files from the remote server: #{e}. Exiting...")
      graceful_exit
    end
    @elog << ErrorHandling.elog_msg("Downloaded contents of 'uploads/' directory from remote host to local temporary directory:")
    Dir.entries(TEMP_DIR).each { |f| @elog << "\t - #{f}" }
  end

  def validate_downloaded_files(temp_dir_path)
    @logger.debug('GsasSync#validate_download_files(): Entry')
    begin
      # Add any directories that match the yyyy_mm_dissertations/ pattern to an array
      # Validate each in turn
      temp_dir = Pathname.new(temp_dir_path)
      validators = []
      temp_dir.children.each do |f|
        if f.basename.to_s.match?(Validator::DISSERTATION_DIR_REGEX)
          puts "#{temp_dir}#{f.basename}/"
          validators.push(Validator.new("#{temp_dir}#{f.basename}/"))
        end
      end
      validators.each do |validator|
        # TODO: do NOT lazy evaluate (e); we want to be able to list ALL of the validation errors so that ALL errors can be
        # addressed by GSAS at once. Otherwise, there could be a situation where they address an issue, try to transfer again,
        # and it fails again for a novel reason -- better if they can know all the errors at one time.
        if validator.all_required_files_present? &&
           validator.undesirable_characters_in_file_paths? &&
           validator.all_accounted_for_in_manifest? &&
           validator.valid_checksums?
          puts 'pass!'
        else
          puts 'fail!'
        end
      end
    rescue StandardError => e
      @logger.fatal("A fatal error occurred while validating the downloaded files: #{e}. Exiting...")
      graceful_exit
    end
  end

  def graceful_exit
    exit(1)
  end

  private

  def load_config_file(config_file)
    config_contents = File.read(config_file)
    @config = YAML.load(config_contents)['config']
  end
end

# frozen_string_literal: true

require 'rainbow'

class GsasSync
  TEMP_DIR = 'temp'
  UPLOADS_DIR = 'uploads'

  def initialize
    GsasSync::Logger.stdout_logger.debug('Initialized GsasSync Instance')
  end

  def move_temp_files
    destination = GsasSync::Config.storage['dev_directory']
    Pathname(TEMP_DIR).each_child do |child_directory|
      puts child_directory.basename
      FileUtils.mv("#{FileUtils.pwd}/#{TEMP_DIR}/#{child_directory.basename}",
                   "#{destination}/#{child_directory.basename}")
    end
    FileUtils.rm_rf TEMP_DIR
  end

  # Attempts to download files from the remote server to a temporary directory
  # Will handle any exceptions that occur, including fatal error
  def download_files_to_temp_dir
    xfer_server = GsasSync::Config.sftp_server_str
    GsasSync::Logger.stdout_logger.debug('GsasSync#download_files_to_temp_dir(): Entry')
    GsasSync::Logger.begin_step('Download files from remote', "Downloading files from remote server #{xfer_server}")

    FileUtils.rm_rf TEMP_DIR if File.directory? TEMP_DIR
    begin
      attempt_download
    rescue StandardError => e
      GsasSync::Logger.log_all_fatal("An error ocurred downloading files from the remote server. Error: #{e}. Exiting...")
      graceful_exit
    end
    GsasSync::Logger.progress('Successful transfer from remote host to local temporary directory')
  end

  # Creates an SFTP session and attempts to download files
  # Raises an exception if any error occurs, which should be caught by the caller
  def attempt_download
    @sftp_client = SftpClient.new
    @sftp_client.connect
    unless @sftp_client.uploads_dir?
      raise GsasSync::Exceptions::SftpClientError, 'Remote transfer server does not have an uploads directory'
    end

    @sftp_client.ls(UPLOADS_DIR) # TODO: dev only
    @sftp_client.dl_recursive(UPLOADS_DIR, TEMP_DIR)
    @sftp_client.disconnect
  end

  def validate_downloaded_files(temp_dir_path)
    GsasSync::Logger.stdout_logger.debug('GsasSync#validate_downloaded_files(): Entry')
    GsasSync::Logger.begin_step('Validating downloaded files')

    validators = init_validators(temp_dir_path)
    raise GsasSync::Exceptions::ValidationError, 'Unable to locate any dissertation directory' if validators.empty?

    result = true
    validators.each do |validator|
      next if validator.run_validations

      result = false
    end
    GsasSync::Logger.log_all('Finished running validations for all downloaded files')
    result
  rescue StandardError => e
    GsasSync::Logger.log_all_fatal("An unexpected fatal error occurred while validating the downloaded files: #{e}. Unable to proceed. Exiting...")
    graceful_exit
  end

  # Identify dissertation directories that were downloaded into the temporary
  # location and create validator instances for each of them
  # Returns an array of validator objects
  def init_validators(temp_dir_path)
    # Add any directories that match the yyyy_mm_dissertations/ pattern
    temp_dir = Pathname.new(temp_dir_path)
    validators = []
    temp_dir.children.each do |f|
      if f.basename.to_s.match?(Validator::DISSERTATION_DIR_REGEX)
        puts "#{temp_dir}#{f.basename}/"
        validators.push(Validator.new("#{temp_dir}#{f.basename}/", @logger))
      end
    end
    validators
  end

  def send_test_email(recipient)
    mailer = EmailClient.new(@config)
    mailer.send_test_email recipient
  end

  def graceful_exit
    GsasSync::Logger.log_all 'Gracefully shutting down...'
    @sftp_client&.disconnect
    GsasSync::Logger.close_progress_log_file
    exit(1)
  end
end

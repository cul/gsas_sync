# frozen_string_literal: true

require 'rainbow'

class GsasSync
  TEMP_DIR = 'temp'
  UPLOADS_DIR = 'uploads'

  def initialize
    GsasSync::Logger.stdout_logger.debug('Initialized GsasSync Instance')
  end

  # Move the downloaded files from the temporary directory to the configurable
  # 'storage' destination (where on the production server to store the files for
  # eventually preservation).
  # This is done by moving each dissertation directory (yyyy_mm_dd_disserations/)
  # to the final storage directory.
  def move_temp_files
    GsasSync::Logger.stdout_logger.debug 'GsasSync#move_temp_files: Entry'
    source = "#{FileUtils.pwd}/#{TEMP_DIR}"
    destination = GsasSync::Config.storage['dev_directory'] # This will be an absolute path
    GsasSync::Logger.log_all "Moving files from #{source} to #{destination}"
    Pathname.new(source).each_child do |child_directory|
      puts "we are moving #{child_directory.basename}"
      FileUtils.mkdir(destination) unless File.directory?(destination)
      FileUtils.mv("#{source}/#{child_directory.basename}", "#{destination}/#{child_directory.basename}", secure: true)
    end
  rescue StandardError => e
    raise(Exceptions::GsasError,
          "An error occurred trying to move the downloaded files to the final storage directory on the local server: Error: #{e}")
  end

  def rm_temp_dir
    temp_dir = Pathname.new("#{FileUtils.pwd}/#{TEMP_DIR}")
    FileUtils.rm_rf(temp_dir) if File.directory?(temp_dir)
  rescue StandardError => e
    raise(Exceptions::GsasError,
          "An error occurred removing the temporary download directory on the local server. Error: #{e}")
  end

  # Attempts to download files from the remote server to a temporary directory
  # Will handle any exceptions that occur, including fatal error
  def download_files_to_temp_dir
    temp_dir = "#{FileUtils.pwd}/#{TEMP_DIR}" # TODO: use abs paths
    GsasSync::Logger.stdout_logger.debug('GsasSync#download_files_to_temp_dir(): Entry')

    FileUtils.rm_rf TEMP_DIR if File.directory? TEMP_DIR
    attempt_download
    GsasSync::Logger.progress('Successful transfer from remote host to local temporary directory')
  rescue StandardError => e
    GsasSync::Logger.log_all_fatal("An error ocurred downloading files from the remote server. Error: #{e}. Exiting...")
    graceful_exit
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
  end

  def validate_downloaded_files(temp_dir_path)
    GsasSync::Logger.stdout_logger.debug('GsasSync#validate_downloaded_files(): Entry')

    validators = init_validators(temp_dir_path)
    raise GsasSync::Exceptions::ValidationError, 'Unable to locate any dissertation directory' if validators.empty?

    valid = true
    validators.each do |validator|
      next if validator.run_validations

      valid = false
    end
    GsasSync::Logger.log_all("Finished running validations for all downloaded files: #{valid ? 'SUCCESS' : 'FAILURE'}")
    valid
  rescue StandardError => e
    GsasSync::Logger.log_all_fatal("An unexpected fatal error occurred while validating the downloaded files: #{e}. Unable to proceed. Exiting...")
    graceful_exit
  end

  def rm_remote_files
    @sftp_client.rm_recursive
  rescue StandardError => e
    raise(Exceptions::SftpClientError,
          "An error occurred trying to delete the transferred files on the remote server. Error: #{e}")
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
        validators.push(Validator.new("#{temp_dir}#{f.basename}/"))
      end
    end
    validators
  end

  def send_failure_email
    GsasSync::Logger.close_progress_log_file
    mail_client.send_failure_email_all
  rescue StandardError => e
    raise(GsasSync::Exceptions::EmailError,
          "An error occurred while sending an email via SMTP. This is problematic as the email was an error notification, and it was unable to send. Please examine logs locally. Error: #{e}")
  end

  def send_success_email
    destination = # This will be an absolute path
      GsasSync::Logger.progress_log_dir_contents(GsasSync::Config.storage['dev_directory'],
                                                 'Successfully downloaded the following files:')
    GsasSync::Logger.close_progress_log_file
    mail_client.send_success_email_all
  rescue StandardError => e
    raise(GsasSync::Exceptions::EmailError,
          "An error occurred while sending an email via SMTP. This email was a notification that the process succeeded. This failure will be logged and the program will now attempt to send a failure email notification. Error: #{e}")
  end

  def send_test_email(recipient)
    mailer = EmailClient.new(@config)
    mailer.send_test_email recipient
  end

  def email_and_exit_failure
    send_failure_email
    graceful_exit
  end

  def email_and_exit_success
    send_success_email
    graceful_exit
  end

  # Gracefully terminates the program, closing any open OS resources
  # Closes the sftp connection and progress log file, if open.
  def graceful_exit
    GsasSync::Logger.stdout_logger.info 'Gracefully shutting down...'
    @sftp_client&.disconnect
    GsasSync::Logger.close_progress_log_file
    exit
  end

  private

  def mail_client
    @mail_client ||= EmailClient.new # TODO: do we need to close this?
  end
end

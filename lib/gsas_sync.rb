# frozen_string_literal: true

require 'rainbow'

class GsasSync
  TEMP_DIR = 'temp'
  UPLOADS_DIR = 'uploads'

  # @preservation_dir : the name of the local directory where files will be downloaded to
  # @uploads_dir : the name of the remote directory containing the yyyy_mm_dissertations directories
  # TODO : delete unsured variable
  def initialize(_temp_dir = TEMP_DIR, uploads_dir = UPLOADS_DIR)
    GsasSync::Logger.stdout_logger.debug('Initialized GsasSync Instance')
    @preservation_dir = Config.storage['directory'] # TODO: change 'dev_directory' to 'directory' for actual preservation dir
    @uploads_dir = uploads_dir
    @downloaded_dirs = [] # Array of strings for each yyyy_mm_dissertations directory that was downloaded. Will be defined after downloading.
  end

  # TODO : this actually isn't the best strategy; the 'dissertations' directory will contain multiple 'yyyy_mm_dissertations'
  #        directories within it. We should instead download to this dissertations directory but save in a folder called
  #        'yyyy_mm_dissertations.temp'. Then the rename_temp_dir function will rename that to 'yyyy_mm_dissertations.temp'
  # Renames the temporary 'dissertations.temp' directory to just 'dissertations'
  # TODO : herem (Monday)
  def rename_temp_dir(src = @temp_dir, dst = @preservation_dir) # TODO : DELETE
    Logger.stdout_logger.debug 'GsasSync#rename_temp_dir: Entry'
    FileUtils.mv src, dst
  end

  def rename_temp_dirs
    Logger.stdout_logger.debug 'GsasSync#rename_temp_dirs: Entry'
    @downloaded_dirs.each do |dir_name|
      FileUtils.mv "#{@preservation_dir}/#{dir_name}.temp", "#{@preservation_dir}/#{dir_name}"
    end
  end

  # Move the downloaded files from the temporary directory to the configurable'storage' destination (where on the
  # production server to store the files for eventually preservation).
  # This is done by moving each dissertation directory (yyyy_mm_dd_disserations/) to the final storage directory.
  def move_temp_files # TODO : DELETE
    GsasSync::Logger.stdout_logger.debug 'GsasSync#move_temp_files: Entry'
    source = "#{FileUtils.pwd}/#{TEMP_DIR}"
    destination = GsasSync::Config.storage['directory'] # This will be an absolute path
    GsasSync::Logger.log_all "Moving files from #{source} to #{destination}"
    Pathname.new(source).each_child do |child_directory|
      FileUtils.mkdir(destination) unless File.directory?(destination)
      FileUtils.mv("#{source}/#{child_directory.basename}", "#{destination}/#{child_directory.basename}", secure: true)
    end
  rescue StandardError => e
    raise(Exceptions::GsasError,
          "An error occurred trying to move the downloaded files to the final storage directory on the local server: Error: #{e}")
  end

  def rm_temp_dirs
    GsasSync::Logger.stdout_logger.debug('GsasSync#rm_remp_dirs(): Entry')
    @downloaded_dirs.each do |dir|
      FileUtils.rm_rf("#{@preservation_dir}/#{dir}.temp") if File.directory?("#{@preservation_dir}/#{dir}.temp")
    end
  rescue StandardError => e
    raise(Exceptions::GsasError,
          "An error occurred removing the temporary download directory on the local server. Error: #{e}")
  end

  # Attempts to download files from the remote server to a temporary directory using the SFTP client
  # Will handle any exceptions that occur, including fatal error
  def download_files_to_temp_dir
    GsasSync::Logger.stdout_logger.debug('GsasSync#download_files_to_temp_dir(): Entry')
    verify_dissertations_directory_exists
    attempt_download
    GsasSync::Logger.progress('Successful transfer from remote host to local temporary directory')
  rescue StandardError => e
    GsasSync::Logger.log_all_fatal("An error ocurred downloading files from the remote server. Error: #{e}. Exiting...")
    email_and_exit_failure
  end

  # Side effect: sets the @downloaded_dirs array based on what was downloaded by the @sftp_client
  def attempt_download
    @sftp_client = SftpClient.new
    @sftp_client.connect
    unless @sftp_client.uploads_dir?
      raise GsasSync::Exceptions::SftpClientError, 'Remote transfer server does not have an uploads directory'
    end

    if @sftp_client.dissertations_dir_already_exists?(@preservation_dir, @uploads_dir)
      raise Exceptions::SftpClientError,
            'The dissertations directory we are trying to download already exists on the local machine.'
    end

    @sftp_client.ls(@uploads_dir)
    @sftp_client.dl_dissertation_dirs_to_temp(@uploads_dir, @preservation_dir)
    @downloaded_dirs = @sftp_client.dissertation_dirs_array
  end

  # Verifies that the preservation directory described in the configuration file exists on the local machine
  # Returns nil. Raises a GsasSync::Exceptions::GsasError if it is not present.
  def verify_dissertations_directory_exists
    return if File.directory? @preservation_dir # TODO: change to directory

    raise GsasSync::Exceptions::GsasError,
          'The directory described in the config file where downloaded files should be stored does not exist on the local machine.'
  end

  # Create Validator objects for each yyyy_mm_dissertations directory and runs all validations, returning the result
  def validate_downloaded_files
    GsasSync::Logger.stdout_logger.debug('GsasSync#validate_downloaded_files(): Entry')

    validators = init_validators
    raise GsasSync::Exceptions::ValidationError, 'Unable to locate any dissertation directory' if validators.empty?

    valid = true
    validators.each do |validator|
      next if validator.run_validations

      valid = false
    end
    GsasSync::Logger.log_all("Finished running validations for all downloaded files: #{valid ? 'SUCCESS ✅' : 'FAILURE ❌'}")
    valid
  rescue StandardError => e
    GsasSync::Logger.log_all_fatal("An unexpected fatal error occurred while validating the downloaded files: #{e}. Unable to proceed. Exiting...")
    email_and_exit_failure
  end

  def rm_remote_files
    @sftp_client.connect
    @downloaded_dirs.each do |dir_name|
      @sftp_client.rm_recursive("#{@uploads_dir}/#{dir_name}")
    end
    @sftp_client.disconnect
  rescue StandardError => e
    raise(Exceptions::SftpClientError,
          "An error occurred trying to delete the transferred files on the remote server. Error: #{e}")
  end

  # Identify dissertation directories that were downloaded into the temporary location and create validator instances
  # for each of them. Returns an array of validator objects
  def init_validators
    GsasSync::Logger.stdout_logger.debug('GsasSync#init_validators(): Entry')
    validators = []
    @downloaded_dirs.each do |dir|
      validators.push(Validator.new(Pathname.new("#{@preservation_dir}/#{dir}.temp")))
    end
    validators
  end

  def send_failure_email
    GsasSync::Logger.close_progress_log_file
    rm_temp_dirs
    mail_client.send_failure_email_all
  rescue StandardError => e
    raise(GsasSync::Exceptions::EmailError,
          "An error occurred while sending an email via SMTP. This is problematic as the email was an error notification, and it was unable to send. Please examine logs locally. Error: #{e}")
  end

  def send_success_email
    GsasSync::Logger.stdout_logger.debug('GsasSync#send_success_email(): Entry')
    GsasSync::Logger.close_progress_log_file
    mail_client.send_success_email_all
  rescue StandardError => e
    raise(GsasSync::Exceptions::EmailError,
          "An error occurred while sending an email via SMTP. This email was a notification that the process succeeded. This failure will be logged and the program will now attempt to send a failure email notification. Error: #{e}")
  end

  def email_and_exit_failure
    GsasSync::Logger.log_all_fatal('Sending failure email notification. This will close the local progress.log file...')
    # TODO : remove dissertations/ ... .temp directory/ies if exists !!!! (YOU are here Tuesady afternoon)
    send_failure_email
  rescue StandardError => e
    GsasSync::Logger.stdout_logger.fatal("#{e.class} - #{e.message}")
    GsasSync::Logger.progress_log_append("#{e.class} - #{e.message}")
  ensure
    graceful_exit
  end

  def email_and_exit_success
    send_success_email
    GsasSync::Logger.stdout_logger.info('The Gsas Sync Process has completed successfully.')
  rescue StandardError => e
    GsasSync::Logger.stdout_logger.fatal("#{e.class} - #{e.message}")
    GsasSync::Logger.progress_log_append("#{e.class} - #{e.message}")
  ensure
    graceful_exit
  end

  # Gracefully terminates the program, closing any open OS resources
  # Closes the sftp connection and progress log file, if open.
  def graceful_exit
    GsasSync::Logger.log_all('Gracefully shutting down...')
    @sftp_client.disconnect unless @sftp_client.nil? || @sftp_client.closed?
    GsasSync::Logger.close_progress_log_file
    exit
  end

  private

  def mail_client
    @mail_client ||= EmailClient.new(GsasSync::Logger.log_file_name) # TODO: do we need to close this?
  end
end

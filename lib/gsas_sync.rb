# frozen_string_literal: true

require 'rainbow'

class GsasSync
  TEMP_DIR = 'temp'
  UPLOADS_DIR = 'uploads'

  # @preservation_dir : the name of the local directory where files will be downloaded to
  # @uploads_dir : the name of the remote directory containing the yyyy_mm_dissertations directories
  def initialize(_temp_dir = TEMP_DIR, uploads_dir = UPLOADS_DIR)
    @preservation_dir = Config.storage_directory # absolute path to directory
    @uploads_dir = uploads_dir
    @downloaded_dirs = [] # Array of strings for each yyyy_mm_dissertations directory that was downloaded
  end

  # rename the downloaded yyyy_mm_dissertations.temp directory by removing the '.temp' suffix
  def rename_temp_dirs
    if Config.dry_run
      Logger.log_all 'DRY RUN: Skipping renaming of temp directories; temp directories will be removed.'
      return
    end
    @downloaded_dirs.each do |dir_name|
      FileUtils.mv "#{@preservation_dir}/#{dir_name}.temp", "#{@preservation_dir}/#{dir_name}"
    end
  end

  # Deletes any .temp directories from the @preservation_dir on the local filesystem
  def rm_temp_dirs
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
    verify_dissertations_directory_exists
    attempt_download
    Logger.progress('Successful transfer from remote host to local temporary directory')
  rescue StandardError => e
    Logger.log_all_fatal("An error occurred downloading files from the remote server. Error: #{e}. Exiting...")
    email_and_exit(success: false) # TODO: move to outer scope
  end

  # Side effect: sets the @downloaded_dirs array based on what was downloaded by the @sftp_client
  def attempt_download
    @sftp_client = SftpClient.new
    @sftp_client.connect
    unless @sftp_client.uploads_dir?
      raise Exceptions::SftpClientError, 'Remote transfer server does not have an uploads directory'
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
    return if File.directory? @preservation_dir

    raise GsasSync::Exceptions::GsasError,
          'The directory described in the config file where downloaded files should be stored does not exist on the local machine.' # rubocop:disable Layout/LineLength
  end

  # Create Validator objects for each yyyy_mm_dissertations directory and runs all validations, returning the result
  def validate_downloaded_files
    validators = init_validators
    if validators.empty?
      raise Exceptions::ValidationError,
            'Unable to locate dissertation directory on remote'
    end

    valid = true
    validators.each do |validator|
      next if validator.run_validations

      valid = false
    end
    Logger.log_all("Finished running validations for all downloaded files: #{valid ? 'SUCCESS ✅' : 'FAILURE ❌'}")
    valid
  rescue StandardError => e
    Logger.log_all_fatal("An unexpected fatal error occurred while validating the downloaded files: #{e}. Unable to proceed. Exiting...") # rubocop:disable Layout/LineLength
    email_and_exit(success: false) # TODO: move to outer scope
  end

  # Identify dissertation directories that were downloaded into the temporary location and create validator instances
  # for each of them. Returns an array of validator objects
  def init_validators
    validators = []
    @downloaded_dirs.each do |dir|
      validators.push(Validator.new(Pathname.new("#{@preservation_dir}/#{dir}.temp")))
    end
    validators
  end

  def rm_remote_files
    if Config.dry_run
      Logger.log_all 'DRY RUN: Skipping deletion of downloaded files from remote transfer server.'
      return
    end
    @sftp_client.connect
    @downloaded_dirs.each do |dir_name|
      @sftp_client.rm_recursive("#{@uploads_dir}/#{dir_name}")
    end
    @sftp_client.disconnect
  rescue StandardError => e
    raise(Exceptions::SftpClientError,
          "An error occurred trying to delete the transferred files on the remote server. Error: #{e}")
  end

  # An exception may occur sending mail
  def email_and_exit(success: true)
    result_str = success ? 'success' : 'failure'
    if Config.dry_run
      Logger.log_all("DRY RUN: Skipping #{result_str} email notification.")
      graceful_exit
    end
    Logger.log_all_fatal("Sending #{result_str} email notification. This will close the progress.log file...")
    Logger.close_progress_log_file
    rm_temp_dirs
    mail_client.make_and_send_email(success: success)
  rescue StandardError => e
    Logger.stdout_logger.fatal("#{e.class} - #{e.message}")
    Logger.progress_log_append("#{e.class} - #{e.message}")
  ensure
    graceful_exit
  end

  # Gracefully terminates the program, closing any open OS resources
  def graceful_exit
    Logger.stdout_logger.info('Gracefully shutting down...')
    @sftp_client.disconnect unless @sftp_client.nil? || @sftp_client.closed?
    Logger.close_progress_log_file
    exit
  end

  def log_summary
    Logger.progress('^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^')
    Logger.progress('^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^')
    Logger.progress('Printing summary of what was downloaded from the remote transfer server:')
    if Config.dry_run
      Logger.progress('(This is a dry run and only temporary downloads were made. This is a summary of what was downloaded, validated, and then deleted.)') # rubocop:disable Layout/LineLength
    end
    temp = Config.dry_run ? '.temp' : ''
    @downloaded_dirs.each do |dir|
      Logger.progress_log_dir_contents("#{Config.storage_directory}/#{dir}#{temp}")
    end
    Logger.progress('The transferred files have been deleted on the remote transfer server')
    Logger.progress('vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv')
    Logger.progress('vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv')
  end

  private

  def mail_client
    @mail_client ||= EmailClient.new(Logger.log_file_name)
  end
end

# frozen_string_literal: true

require 'net/sftp'

class SftpClient
  def initialize
    sftp_server = GsasSync::Config.sftp_server
    @host = sftp_server['host']
    @user = sftp_server['user']
    @key = sftp_server['key']
  end

  def connect
    GsasSync::Logger.stdout_logger.debug("Connecting to #{@user}@#{@host}...")
    begin
      sftp_client.connect!
    rescue StandardError => e
      raise GsasSync::Exceptions::SftpClientError, "Error while connecting to #{@user}@#{@host}. #{error_string(e)}"
    end
    GsasSync::Logger.stdout_logger.info("SFTP connection established with #{@user}@#{@host}")
  end

  # Closes the SFTP connection and SSH connection if they are open
  # TODO: leave ssh session open...
  def disconnect
    GsasSync::Logger.stdout_logger.debug 'Closing SFTP connection...'
    begin
      @sftp_client.close_channel unless @sftp_client.closed?
      @ssh_session.close unless @ssh_session.closed?
    rescue StandardError => e
      raise GsasSync::Exceptions::SftpClientError, "Error trying to close sftp/ssh connection. #{error_string(e)}"
    end
    GsasSync::Logger.stdout_logger.info "Connection with #{@user}@#{@host} closed."
  end

  def closed?
    return true if @sftp_client.nil?

    @sftp_client.closed?
  end

  def sftp_client
    @sftp_client ||= Net::SFTP::Session.new(ssh_session)
  rescue StandardError => e
    raise GsasSync::Exceptions::SftpClientError, "Error trying to start an SFTP session. #{error_string(e)}"
  end

  def ssh_session
    @ssh_session = Net::SSH.start(@host, @user, keys: [@key])
  rescue StandardError => e
    raise GsasSync::Exceptions::SftpClientError, "Error trying to start an SSH session. #{error_string(e)}"
  end

  # For each yyyy_mm_dissertations/ directory on the remote src, download it to
  # local_dst/yyyy_mm_dissertations.temp/
  # Side effect: sets the @dissertation_dirs instance variable
  def dl_dissertation_dirs_to_temp(remote_uploads_dir, local_dissertations_dir)
    GsasSync::Logger.stdout_logger.debug('dl_dissertation_dirs_to_temp(): Entry')
    @dissertation_dirs = []
    # Determine how many yyyy_mm_dissertations directories are present on the remote
    sftp_client.dir.foreach(remote_uploads_dir) do |entry|
      @dissertation_dirs.push(entry.name) if entry.name.match?(Validator::DISSERTATION_DIR_REGEX)
    end
    # Download each of those remote yyyy_mm_dissertations directories to local as .temp directories
    @dissertation_dirs.each do |dir_name|
      dl_recursive("#{remote_uploads_dir}/#{dir_name}", "#{local_dissertations_dir}/#{dir_name}.temp")
    end
  rescue StandardError => e
    raise e
  end

  # The @dissertation_dirs instance variable is set by SftpClient#dl_dissertation_dirs_to_temp
  def dissertation_dirs_array
    return @dissertation_dirs unless @dissertation_dirs.nil?

    raise GsasSync::Exceptions::SftpClientError, 'The array of dissertations directories has not yet been defined'
  end

  # See "Progress Monitoring" section of docs for Net::SFTP::Operations::Download
  # remote_src and local_dst are absolute path strings TODO : change this w File.basename(path)
  def dl_recursive(remote_src, local_dst) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    GsasSync::Logger.log_all "Beginning SFTP download: [remote]/#{remote_src} -> [local]/#{local_dst}"
    begin
      sftp_client.download!(remote_src, local_dst, recursive: true) do |event, _downloader, *args|
        case event
        when :open
          # args[0] : file metadata
          GsasSync::Logger.stdout_logger.debug("starting download: #{args[0].remote} -> #{args[0].local} (#{args[0].size} bytes}")
        when :get
          # args[0] : file metadata
          # args[1] : byte offset in remote file
          # args[2] : data that was received
          GsasSync::Logger.stdout_logger.debug "writing #{args[2].length} bytes to #{args[0].local} starting at #{args[1]}"
        when :close
          # args[0] : file metadata
          GsasSync::Logger.stdout_logger.debug("finished with #{args[0].remote}")
          GsasSync::Logger.progress(" - #{args[0].local}")
        when :mkdir
          # args[0] : local path name
          GsasSync::Logger.stdout_logger.debug "creating directory #{args[0]}"
        when :finish
          GsasSync::Logger.stdout_logger.debug "All done! Files transfered from #{remote_src} -> #{local_dst}"
        end
      end
    rescue StandardError => e
      raise GsasSync::Exceptions::SftpClientError, "Error while downloading files via SFTP. #{error_string(e)}"
    end
    GsasSync::Logger.log_all("Downloaded files from #{@user}@#{@host}:#{remote_src}/ -> #{local_dst}/")
  end

  # rm_recursive uses an open @sftp_client
  # Recursively delete all the contents of the given directory, and then the directory itself
  # TODO : you cannot just do entry.name in the block passed to glob...each
  # you need THE FULL PATH TO THE FILE on the remote, so we need to make that string
  def rm_recursive(directory)
    GsasSync::Logger.log_all("Removing the #{directory} directory on the remote server...")
    # First delete all files
    puts 'first we do files'
    sftp_client.dir.glob(directory, '**/*') do |entry|
      if entry.file?
        puts "rm-ing file #{directory}/#{entry.name}!"
        @sftp_client.remove!("#{directory}/#{entry.name}") # TODO: uncomment when ready
        # @sftp_client.remove(entry.name).wait # TODO: uncomment when ready
      end
    end
    # Second delete all directories (For why, see documentation for #rmdir and #rmdir! : https://net-ssh.github.io/net-sftp/)
    puts 'now directories'
    sftp_client.dir.glob(directory, '**/*').sort_by { |path| -1 * path.name.split('/').length }.each do |entry|
      next if ['.', '..'].include?(entry.name)

      next unless entry.directory?

      puts "rm-ing directory #{directory}/#{entry.name}!"
      # TODO : an exception happens here because directories need to be empty! So, we need to delete the innermost-nested directories first!
      #        And how do we do that? First thought is a recursive algorithm... Not sure...
      @sftp_client.rmdir!("#{directory}/#{entry.name}") # TODO: uncomment when ready
      # @sftp_client.rmdir(entry.name).wait # TODO: uncomment when ready
    end
    @sftp_client.rmdir!(directory)
  rescue StandardError => e
    puts 'rescued error from rm_recursive. exiting...'
    puts e
    exit(1)
  end

  def uploads_dir?
    sftp_client.dir.foreach('.') do |entry|
      return true if entry.name == 'uploads' && entry.directory?
    end
    false
  end

  # Returns true if there is any yyyy_mm_dissertations directory in the local server preservation directory that has
  # the same name as a yyyy_mm_dissertations directory in the uploads/ directory of the remote SFTP server.
  # If the directory of that name is already on the local machine, perhaps it has already been downloaded.
  # Regardless of why this occurrs, execution most likely cannot continue, as attempting to download the directory would
  # cause a naming collision with the extent one.
  # params:
  #  - preservation_dir : absolute path of the preservations directory on the local machine
  #  - uploads : name of the directory on the remote that contains the yyyy_mm_dissertations directories
  def dissertations_dir_already_exists?(preservation_dir, uploads = 'uploads')
    GsasSync::Logger.stdout_logger.debug('GsasSync::SftpClient#dissertations_dir_already_exists(): Entry')
    remote_dissertation_directories = []
    sftp_client.dir.foreach(uploads) do |entry|
      remote_dissertation_directories.push(entry.name) if entry.name.match?(Validator::DISSERTATION_DIR_REGEX)
    end
    p remote_dissertation_directories
    remote_dissertation_directories.each do |match|
      return true if File.directory?("#{preservation_dir}/#{match}")
    end
    false
  end

  # directory : string name of the directory (not an absolute path)
  def ls(directory = '.')
    GsasSync::Logger.stdout_logger.info "`ls -la #{directory}` on remote server :"
    sftp_client.dir.foreach(directory) do |entry|
      GsasSync::Logger.stdout_logger.info "\t#{entry.longname}"
    end
  rescue StandardError => e
    raise GsasSync::Exceptions::SftpClientError,
          "Error while trying to run `ls -la` on remote transfer server. #{error_string(e)}"
  end

  private

  def error_string(err)
    "Error [#{err.class.name}] : #{err.message}"
  end
end

# TODO: in close use safe navigation op ... ?

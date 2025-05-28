# frozen_string_literal: true

require 'net/sftp'

class SftpClient
  include GsasSync::Utils

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

  def sftp_client
    # raise 'test error'
    @sftp_client ||= Net::SFTP::Session.new(ssh_session)
  rescue StandardError => e
    raise GsasSync::Exceptions::SftpClientError, "Error trying to start an SFTP session. #{error_string(e)}"
  end

  def ssh_session
    @ssh_session = Net::SSH.start(@host, @user, keys: [@key])
  rescue StandardError => e
    raise GsasSync::Exceptions::SftpClientError, "Error trying to start an SSH session. #{error_string(e)}"
  end

  # See "Progress Monitoring" section of docs for Net::SFTP::Operations::Download
  def dl_recursive(remote_src, local_dst) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    GsasSync::Logger.log_all "Beginning SFTP download: [remote]/#{remote_src} -> [local]/#{local_dst}"
    begin
      @sftp_client.download!(remote_src, local_dst, recursive: true) do |event, _downloader, *args|
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

  def rm_recursive
    # TODO: implement function to remove all copied files from sftp server
  end

  def uploads_dir?
    @sftp_client.dir.foreach('.') do |entry|
      return true if entry.name == 'uploads' && entry.directory?
    end
    false
  end

  def ls(directory = '.')
    GsasSync::Logger.stdout_logger.info "`ls -la #{directory}` on remote server :"
    @sftp_client.dir.foreach(directory) do |entry|
      GsasSync::Logger.stdout_logger.info "\t#{entry.longname}"
    end
  rescue StandardError => e
    raise GsasSync::Exceptions::SftpClientError,
          "Error while trying to run `ls -la` on remote transfer server. #{error_string(e)}"
  end
end

# TODO: in close use safe navigation op

# frozen_string_literal: true

require 'net/sftp'

class SftpClient
  def initialize(config, logger)
    @logger = logger
    @host = config['sftp_server']['host']
    @user = config['sftp_server']['user']
    @key = config['sftp_server']['key']
  end

  def connect
    @logger.debug("Connecting to #{@user}@#{@host}...")
    sftp_client.connect!
    @logger.info("SFTP connection established with #{@user}@#{@host}")
  end

  # Closes the SFTP connection and SSH connection if they are open
  # TODO: leave ssh session open...
  def disconnect
    # raise StandardError.new('fake error')
    @logger.debug 'Closing SFTP connection...'
    @sftp_client.close_channel unless @sftp_client.closed?
    @ssh_session.close unless @ssh_session.closed?
    @logger.info "Connection with #{@user}@#{@host} closed."
  end

  def sftp_client
    @sftp_client ||= Net::SFTP::Session.new(ssh_session)
  end

  def ssh_session
    @ssh_session = Net::SSH.start(@host, @user, keys: [@key])
  end

  # See "Progress Monitoring" section of docs for Net::SFTP::Operations::Download
  def dl_recursive(remote_src, local_dst) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    @logger.debug "SftpClient#dl_recursive(): Beginning SFTP download: [remote]/#{remote_src} -> [local]/#{local_dst}"
    @sftp_client.download!(remote_src, local_dst, recursive: true) do |event, _downloader, *args|
      case event
      when :open
        # args[0] : file metadata
        @logger.debug("starting download: #{args[0].remote} -> #{args[0].local} (#{args[0].size} bytes}")
        # puts_t.call "starting download: #{args[0].remote} -> #{args[0].local} (#{args[0].size} bytes}"
        # puts ':open' # TODO: dev
        # p args # TODO: dev
      when :get
        # args[0] : file metadata
        # args[1] : byte offset in remote file
        # args[2] : data that was received
        @logger.debug "writing #{args[2].length} bytes to #{args[0].local} starting at #{args[1]}"
        # puts_t.call "writing #{args[2].length} bytes to #{args[0].local} starting at #{args[1]}"
        # puts ':get' # TODO: dev
        # p args # TODO: dev
      when :close
        # args[0] : file metadata
        @logger.debug("finished with #{args[0].remote}")
        # puts_t.call "finished with #{args[0].remote}"
        # puts ':close' # TODO: dev
        # p args # TODO: dev
      when :mkdir
        # args[0] : local path name
        @logger.debug "creating directory #{args[0]}"
        # puts_t.call "creating directory #{args[0]}"
        # puts ':mkdir' # TODO: dev
        # p args # TODO: dev
      when :finish
        @logger.debug "All done! Files transfered from #{remote_src} -> #{local_dst}"
        # puts "#{GsasSync::TERM_PREFIX} all done! ========================================="
        # puts ':finish' # TODO: dev
        # p args # TODO: dev
      end
    end
    @logger.info("Downloaded files from #{@user}@#{@host}:#{remote_src} -> #{local_dst} ")
  end

  def ls(directory = '.')
    @logger.debug('SftpClient#ls(): Entry')
    puts "#{GsasSync::TERM_PREFIX} `ls -la #{directory}` on remote server :"
    @sftp_client.dir.foreach(directory) do |entry|
      puts "\t#{entry.longname}"
    end
  end
end

# frozen_string_literal: true

require 'net/sftp'

class SftpClient
  TERM_PREFIX = '[gsas_sync]'

  def initialize(config)
    @host = config['sftp_server']['host']
    @user = config['sftp_server']['user']
    @key = config['sftp_server']['key']
  end

  def connect
    begin
      sftp_client.connect!
    rescue StandardError => e
      puts "#{TERM_PREFIX} Failed to connect to #{@user}@#{@host}\n#{e}"
      exit(1)
    end
    puts "#{TERM_PREFIX} SFTP connection established with #{@user}@#{@host}"
  end

  def disconnect
    @sftp_client.close_channel
  end

  def sftp_client
    @sftp_client ||= Net::SFTP::Session.new(ssh_session)
  end

  def ssh_session
    @ssh_session = Net::SSH.start(@host, @user, keys: [@key])
  end

  # See "Progress Monitoring" section of docs for Net::SFTP::Operations::Download
  def dl_recursive(remote_src, local_dst) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    puts_t = ->(str) { puts "#{TERM_PREFIX}\t#{str}" } # For indenting our output
    puts "#{TERM_PREFIX} Beginning SFTP download..."
    @sftp_client.download!(remote_src, local_dst, recursive: true) do |event, _downloader, *args|
      case event
      when :open
        # args[0] : file metadata
        puts_t.call "starting download: #{args[0].remote} -> #{args[0].local} (#{args[0].size} bytes}"
        # puts ':open' # TODO: dev
        # p args # TODO: dev
      when :get
        # args[0] : file metadata
        # args[1] : byte offset in remote file
        # args[2] : data that was received
        puts_t.call "writing #{args[2].length} bytes to #{args[0].local} starting at #{args[1]}"
        # puts ':get' # TODO: dev
        # p args # TODO: dev
      when :close
        # args[0] : file metadata
        puts_t.call "finished with #{args[0].remote}"
        # puts ':close' # TODO: dev
        # p args # TODO: dev
      when :mkdir
        # args[0] : local path name
        puts_t.call "creating directory #{args[0]}"
        # puts ':mkdir' # TODO: dev
        # p args # TODO: dev
      when :finish
        puts_t.call 'all done!'
        # puts ':finish' # TODO: dev
        # p args # TODO: dev
      end
    end
  end

  def ls(directory = '.')
    puts "#{TERM_PREFIX} `ls -la #{directory}` on remote server :"
    @sftp_client.dir.foreach(directory) do |entry|
      puts entry.longname
    end
  end
end

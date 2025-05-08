# frozen_string_literal: true

require 'net/sftp'

class SftpClient
  def initialize(config)
    @host = config['sftp_server']['host']
    @user = config['sftp_server']['user']
  end

  def connect
    sftp_client.connect!
  rescue StandardError => e
    puts "Failed to connect to #{@user}@#{@host}"
    p e
  end

  def disconnect
    @sftp_client.close_channel
  end

  def sftp_client
    @sftp_client ||= Net::SFTP::Session.new(ssh_session)
  end

  def ssh_session
    @ssh_session = Net::SSH.start(@host, @user, keys: ['~/.ssh/stagexfer-id_ed25519'])
  end

  def ls(dir = '.')
    @sftp_client.dir.foreach(dir) do |entry|
      puts entry.longname
    end
  end
end

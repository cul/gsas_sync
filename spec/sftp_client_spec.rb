# frozen_string_literal: true

# require 'spec_helper'
# require 'net/sftp'

RSpec.describe SftpClient do
  let(:config) { YAML.load(File.read('spec/fixtures/config.yml'))['config'] }
  let(:client) { described_class.new(config) }

  describe '#connect' do
    let(:mock_sftp) { instance_double(Net::SFTP::Session) }

    it 'Prints message upon success' do
      allow(client).to receive(:sftp_client).and_return(mock_sftp)
      allow(mock_sftp).to receive(:connect!).and_return(true)
      expect {
        client.connect
      }.to output("[gsas_sync] SFTP connection established with test_user@test_sftp_server\n").to_stdout
    end

    it 'Prints an exception to stdout if unable to connect to remote host' do
      expect {
        client.connect
      }.to output("[gsas_sync] Failed to connect to test_user@test_sftp_server\n").to_stdout
    end

    it 'Exits if unable to connect to remote host' do
      expect { client.connect }.to raise_error(SystemExit)
    end
  end

  describe '#disconnect' do
    it 'invokes Net::SFTP::Session#close_session' do
    end
  end

  describe '#sftp_client' do
    it 'invokes #ssh_session when @sftp_client is nil' do
      let(:mock_ssh_session) { instance_double(Net::SSH::Session) }
      allow(client).to receive(:ssh_session).and_return(mock_ssh_session)

      expect { client.sftp_client }.to have_received(:ssh_sesion)
    end
  end

  describe '#ssh_session' do
    let(:mock_ssh_session) { instance_double(Net::SSH::Session) }

    it 'returns a new SSH session object on success' do
      allow(Net::SSH).to receive(:start)
        .with('test_sftp_server', 'test_user', keys: ['path/to/key'])
        .and_return(mock_ssh_session)
    end
  end

  describe '#dl_recursive' do
    it 'invokes Net::SFTP::Session#download!' do
    end
  end

  describe '#ls' do
    it 'invokes Net::SFTP::Session#dir' do
    end

    it 'prints the directories to standard out' do
    end
  end
end

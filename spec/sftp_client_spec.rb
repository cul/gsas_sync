# frozen_string_literal: true

require 'spec_helper'
require 'net/sftp'

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

  describe '#disconnect', focus: true do
    let(:mock_sftp_session) { instance_double(Net::SFTP::Session) }

    it 'invokes Net::SFTP::Session#close_session' do
      # expect { client.disconnect }.to have_received(:close_channel)
      client.instance_variable_set(:@sftp_client, mock_sftp_session)
      expect(mock_sftp_session).to receive(:close_channel)
      client.disconnect
    end
  end

  describe '#sftp_client' do
    let(:mock_ssh_session) { instance_double(Net::SSH::Connection::Session) }
    let(:mock_sftp) { instance_double(Net::SFTP::Session) }

    it 'invokes #ssh_session when @sftp_client is nil' do
      allow(client).to receive(:ssh_session).and_return(mock_ssh_session)
      allow(Net::SFTP::Session).to receive(:new).and_return(:mock_sftp)

      expect(client).to receive(:ssh_session)
      client.sftp_client
      # expect { client.sftp_client }.to have_received(:ssh_sesion)
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

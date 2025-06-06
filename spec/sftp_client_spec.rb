# frozen_string_literal: true

require 'spec_helper'
require 'net/sftp'

RSpec.describe SftpClient do
  let(:config) { YAML.load(File.read('spec/fixtures/config.yml'))['config'] }
  let(:mock_logger) { instance_double(GsasSync::Logger) }
  let(:mock_local_logger) { instance_double(Logger) }
  let(:client) { described_class.new(config, mock_logger) }

  before do
    allow(mock_logger).to receive(:log_all).and_return nil
    allow(mock_logger).to receive(:progress).and_return nil
    allow(mock_logger).to receive(:local).and_return mock_local_logger
    allow(mock_local_logger).to receive(:debug).and_return nil
    allow(mock_local_logger).to receive(:info).and_return nil
  end

  describe '#connect' do
    let(:mock_sftp) { instance_double(Net::SFTP::Session) }

    it 'Returns nil on success' do
      allow(client).to receive(:sftp_client).and_return(mock_sftp)
      allow(mock_sftp).to receive(:connect!).and_return(true)
      expect(client.connect).to be(nil)
    end

    it 'Raises an SftpClientError when unable to connect to remote host' do
      expect {
        client.connect
      }.to raise_error(GsasSync::Exceptions::SftpClientError)
    end

    # TODO: Here
    it 'Exits if unable to connect to remote host' do
      expect { client.connect }.to raise_error(SystemExit)
    end
  end

  describe '#disconnect' do
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

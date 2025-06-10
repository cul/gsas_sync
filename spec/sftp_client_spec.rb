# frozen_string_literal: true

require 'spec_helper'
require 'net/sftp'

RSpec.describe SftpClient do
  # GLOBAL TESTING OBJECTS (ALL OTHERS SCOPED TO EXAMPLE GROUPS OR EXAMPLES)
  test_directory = 'test_directory'
  let(:logger_double) { instance_double(Logger) }
  let(:sftp_session_double) { instance_double(Net::SFTP::Session) }
  let(:ssh_session_double) { instance_double(Net::SSH::Connection::Session) }
  let(:fake_dir1) { instance_double(Net::SFTP::Protocol::V01::Name, name: '2025_05_dissertations') }
  let(:fake_dir2) { instance_double(Net::SFTP::Protocol::V01::Name, name: 'bad_name_dissertations') }
  let(:fake_dir) do
    instance_double(Net::SFTP::Protocol::V01::Name, name: '2025_05_dissertations', file?: false, directory?: true)
  end
  let(:fake_uploads_dir) do
    instance_double(Net::SFTP::Protocol::V01::Name, name: 'uploads', file?: false, directory?: true)
  end
  let(:fake_dir_self) do
    instance_double(Net::SFTP::Protocol::V01::Name, name: '.', file?: false, directory?: true)
  end
  let(:fake_dir_parent) do
    instance_double(Net::SFTP::Protocol::V01::Name, name: '..', file?: false, directory?: true)
  end
  let(:fake_file) do
    instance_double(Net::SFTP::Protocol::V01::Name, name: 'dissertation.pdf', file?: true, directory?: false)
  end
  let(:dir_double) { instance_double(Net::SFTP::Operations::Dir) }
  let(:test_sftp_client) { described_class.new }

  before do
    # Mock logging
    allow(GsasSync::Logger).to receive(:stdout_logger).and_return(logger_double)
    allow(logger_double).to receive(:debug)
    allow(logger_double).to receive(:info)
    # Mock config
    allow(GsasSync::Config).to receive(:sftp_server).and_return({ host: 'test_sftp_server', user: 'test_user',
                                                                  key: 'path/to/key' })

    # Class-specific mock objects
    allow(test_sftp_client).to receive(:sftp_session).and_return(sftp_session_double)
    allow(sftp_session_double).to receive(:dir).and_return(dir_double)
  end

  # TESTS
  describe '#initialize' do
    it 'reads the config to set values' do
      expect(GsasSync::Config).to receive(:sftp_server).once
      described_class.new
    end
  end

  describe '#connect' do
    it 'raises an SftpClientError when it cannot connect' do
      allow(sftp_session_double).to receive(:connect!).and_raise(StandardError)

      expect { test_sftp_client.connect }.to raise_error(GsasSync::Exceptions::SftpClientError)
    end
  end

  describe '#disconnect' do
    it 'raises an SftpClientError when it cannot close the sftp connection' do
      test_sftp_client.instance_variable_set(:@sftp_session, sftp_session_double)
      test_sftp_client.instance_variable_set(:@ssh_session, ssh_session_double)
      allow(sftp_session_double).to receive(:closed?).and_return(false)
      allow(sftp_session_double).to receive(:close_channel).and_raise(StandardError)

      expect { test_sftp_client.disconnect }.to raise_error(GsasSync::Exceptions::SftpClientError)
      expect(ssh_session_double).not_to receive(:closed?)
      expect(ssh_session_double).not_to receive(:close)
    end

    it 'raises an SftpClientError when it cannot close the ssh connection' do
      test_sftp_client.instance_variable_set(:@sftp_session, sftp_session_double)
      test_sftp_client.instance_variable_set(:@ssh_session, ssh_session_double)

      allow(sftp_session_double).to receive(:closed?).and_return(false)
      allow(sftp_session_double).to receive(:close_channel)
      allow(ssh_session_double).to receive(:closed?).and_return(false)
      allow(ssh_session_double).to receive(:close).and_raise(StandardError)

      expect { test_sftp_client.disconnect }.to raise_error(GsasSync::Exceptions::SftpClientError)
    end
  end

  describe '#closed?' do
    it 'returns true if @sftp_session is nil' do
      test_sftp_client.instance_variable_set(:@sftp_session, sftp_session_double)
      allow(sftp_session_double).to receive(:nil?).and_return(true)

      expect(test_sftp_client.closed?).to be(true)
    end

    it 'returns calls Net::Sftp::Session#closed? if @sftp_session is not nil' do
      test_sftp_client.instance_variable_set(:@sftp_session, sftp_session_double)
      allow(sftp_session_double).to receive(:nil?).and_return(false)
      allow(sftp_session_double).to receive(:closed?)

      expect(sftp_session_double).to receive(:closed?) # Broken
      test_sftp_client.closed?
    end
  end

  describe '#sftp_session' do
    it 'instantiates a new Net::SFTP::Session instance if the instance variable is nil' do
      test_sftp_client = described_class.new
      test_sftp_client.instance_variable_set(:@sftp_session, nil)
      allow(test_sftp_client).to receive(:ssh_session)
      allow(Net::SFTP::Session).to receive(:new)

      expect(Net::SFTP::Session).to receive(:new)
      test_sftp_client.sftp_session
    end

    it 'Raises an SftpClientError if #ssh_session raises error' do
      test_sftp_client = described_class.new
      test_sftp_client.instance_variable_set(:@sftp_session, nil)
      allow(test_sftp_client).to receive(:ssh_session).and_raise(StandardError)

      expect(Net::SFTP::Session).not_to receive(:new)
      expect { test_sftp_client.sftp_session }.to raise_error(GsasSync::Exceptions::SftpClientError)
    end

    it 'Raises an SftpClientError if Net::SFTP::Session.new raises error' do
      test_sftp_client = described_class.new
      test_sftp_client.instance_variable_set(:@sftp_session, nil)
      allow(test_sftp_client).to receive(:ssh_session).and_raise(StandardError)
      allow(Net::SFTP::Session).to receive(:new).and_raise(StandardError)

      expect { test_sftp_client.sftp_session }.to raise_error(GsasSync::Exceptions::SftpClientError)
    end
  end

  describe '#ssh_session' do
    it 'raises an SftpClientError if Net::SSH::start raises an error' do
      test_sftp_client = described_class.new
      test_sftp_client.instance_variable_set(:@ssh_session, nil)
      allow(Net::SSH).to receive(:start).and_raise(StandardError)

      expect { test_sftp_client.ssh_session }.to raise_error(GsasSync::Exceptions::SftpClientError)
    end
  end

  describe '#dl_dissertation_dirs_to_temp' do
    before do
      allow(dir_double).to receive(:foreach).and_yield(fake_dir1).and_yield(fake_dir2)
    end

    it 'adds correctly-formatted directories to the @dissertation_dirs instance variable' do
      allow(test_sftp_client).to receive(:dl_recursive)

      test_sftp_client.dl_dissertation_dirs_to_temp('remote_src', 'local_dst')

      expect(test_sftp_client.instance_variable_get(:@dissertation_dirs)).to include(fake_dir1.name)
      expect(test_sftp_client.instance_variable_get(:@dissertation_dirs)).not_to include(fake_dir2.name)
    end

    it 'raises an error if #dl_recursive raises an error' do
      allow(test_sftp_client).to receive(:dl_recursive).and_raise(StandardError, 'custom error')

      expect {
        test_sftp_client.dl_dissertation_dirs_to_temp('remote_src',
                                                      'local_dst')
      }.to raise_error(StandardError, 'custom error')
    end
  end

  describe '#dl_recursive' do
    it 'raises an SftpClientError when Net::Sftp::Session#download! raises an error' do
      # test_sftp_client = described_class.new
      # allow(test_sftp_client).to receive(:sftp_session).and_return(sftp_session_double)
      allow(sftp_session_double).to receive(:download!).and_raise(StandardError)

      expect {
        test_sftp_client.dl_recursive('remote_src', 'local_dst')
      }.to raise_error(GsasSync::Exceptions::SftpClientError)
    end
  end

  describe '#rm_recursive' do
    let(:glob_array) { [fake_dir, fake_dir_self, fake_dir_parent, fake_file] }

    # test_sftp_client = described_class.new

    before do
      allow(dir_double).to receive(:glob).and_return(glob_array)
      allow(sftp_session_double).to receive(:remove!)
      allow(sftp_session_double).to receive(:rmdir!)
    end

    it 're-raises any errors caught removing files' do
      allow(sftp_session_double).to receive(:remove!).with("#{test_directory}/#{fake_file.name}")
                                                     .and_raise(StandardError, 'custom error')

      expect { test_sftp_client.rm_recursive(test_directory) }.to raise_error(StandardError, 'custom error')
    end

    it 're-raises any errors caught removing directories' do
      allow(sftp_session_double).to receive(:rmdir!).with("#{test_directory}/#{fake_dir.name}").and_raise(
        StandardError, 'custom error'
      )

      expect { test_sftp_client.rm_recursive(test_directory) }.to raise_error(StandardError, 'custom error')
    end

    it "skips removing '.' and '..' directories" do
      expect(sftp_session_double).not_to receive(:rmdir!).with(fake_dir_self)
      expect(sftp_session_double).not_to receive(:rmdir!).with(fake_dir_parent)

      test_sftp_client.rm_recursive(test_directory)
    end
  end

  describe '#uploads_dir?' do
    before do
      allow(sftp_session_double).to receive(:dir).and_return(dir_double)
    end

    it 'returns true if uploads dir entry is yielded by sftp_session.dir.foreach' do
      allow(dir_double).to receive(:foreach).and_yield(fake_dir_self).and_yield(fake_dir_parent)
                                            .and_yield(fake_uploads_dir).and_yield(fake_file)

      expect(test_sftp_client.uploads_dir?).to be(true)
    end

    it 'returns false if there is no uploads dir yielded to the block' do
      allow(dir_double).to receive(:foreach).and_yield(fake_dir_self).and_yield(fake_dir_parent)
                                            .and_yield(fake_file)

      expect(test_sftp_client.uploads_dir?).to be(false)
    end
  end

  describe '#dissertation_dirs_array' do
    it 'returns the instance variable if not nil' do
      test_sftp_client.instance_variable_set(:@dissertation_dirs, [1, 2, 3])

      expect(test_sftp_client.dissertation_dirs_array).not_to be(nil)
    end

    it 'raises an SftpClientError if the array is not yet defined (nil)' do
      test_sftp_client = described_class.new

      expect { test_sftp_client.dissertation_dirs_array }.to raise_error(GsasSync::Exceptions::SftpClientError)
    end
  end

  describe '#dissertations_dir_already_exists?' do
    test_preservation_dir = 'test_preservation_dir '
    test_uploads = 'test_uploads '
    it 'returns true if the dissertation directory found on remote is present in preservation directory on local machine' do # rubocop:disable Layout/LineLength
      allow(dir_double).to receive(:foreach).with(test_uploads)
                                            .and_yield(fake_dir_self)
                                            .and_yield(fake_dir)
                                            .and_yield(fake_uploads_dir)
                                            .and_yield(fake_file)
      allow(File).to receive(:directory?).and_return(false)
      allow(File).to receive(:directory?).with("#{test_preservation_dir}/#{fake_dir.name}").and_return(true)

      expect(test_sftp_client.dissertations_dir_already_exists?(test_preservation_dir, test_uploads)).to be(true)
    end

    it 'returns false if the dissertation directory found on remote is not present in preservation directory on local machine' do # rubocop:disable Layout/LineLength
      allow(dir_double).to receive(:foreach).with(test_uploads)
                                            .and_yield(fake_dir_self)
                                            .and_yield(fake_dir)
                                            .and_yield(fake_uploads_dir)
                                            .and_yield(fake_file)
      allow(File).to receive(:directory?).and_return(false)

      expect(test_sftp_client.dissertations_dir_already_exists?(test_preservation_dir, test_uploads)).to be(false)
    end
  end

  describe '#ls' do
    it 'raises an SftpClientError if any exceptions occur' do
      allow(test_sftp_client).to receive(:sftp_session).and_raise(StandardError, 'custom error')

      expect { test_sftp_client.ls }.to raise_error(GsasSync::Exceptions::SftpClientError)
    end

    it 'logs each file in the array to stdout' do
      allow(fake_dir_self).to receive(:longname)
      allow(fake_dir).to receive(:longname)
      allow(fake_uploads_dir).to receive(:longname)
      allow(fake_file).to receive(:longname)
      allow(dir_double).to receive(:foreach).with('.')
                                            .and_yield(fake_dir_self)
                                            .and_yield(fake_dir)
                                            .and_yield(fake_file)
                                            .and_yield(fake_uploads_dir)

      # log info at the top of the method, then once for each entry
      expect(logger_double).to receive(:info).exactly(1 + 4).times
      test_sftp_client.ls
    end
  end
end

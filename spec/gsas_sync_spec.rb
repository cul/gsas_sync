# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GsasSync do
  # GLOBAL TESTING OBJECTS (ALL OTHERS SCOPED TO EXAMPLE GROUPS OR EXAMPLES)
  let(:logger_double) { instance_double(Logger) }
  let(:test_gsas_sync) { described_class.new }
  let(:test_downloaded_dirs) { ['2000_01_dissertations'] }
  let(:mail_client_double) { instance_double(GsasSync::EmailClient) }

  before do
    allow(GsasSync::Logger).to receive(:log_all_fatal)
    allow(GsasSync::Logger).to receive(:log_all)
    allow(GsasSync::Logger).to receive(:stdout_logger).and_return(logger_double)
    allow(logger_double).to receive(:info)
    allow(logger_double).to receive(:debug)
    allow(logger_double).to receive(:fatal)

    allow(GsasSync::Config).to receive(:storage_directory).and_return('path/to/storage/directory')
    allow(GsasSync::Config).to receive(:dry_run).and_return(false) # Override in example groups for dry run testing
  end

  describe '#initialize' do
    it 'reads the config to set directory value' do
      expect(GsasSync::Config).to receive(:storage_directory)
      test_gsas_sync
    end
  end

  context 'in method that interacts with the Filesystem' do
    let(:temp_preservation_dir) { Pathname.new(Dir.mktmpdir('dissertations')) }

    before do
      FileUtils.mkdir(temp_preservation_dir.join('2000_01_dissertations.temp'))
      File.write(temp_preservation_dir.join('2000_01_dissertations.temp/2000_01_items.csv'), 'item data')
      File.write(temp_preservation_dir.join('2000_01_dissertations.temp/2000_01_assets.csv'), 'asset data')
      File.write(temp_preservation_dir.join('2000_01_dissertations.temp/manifest-sha256.txt'), 'manifest data')
      FileUtils.mkdir(temp_preservation_dir.join('2000_01_dissertations.temp/data'))
      File.write(temp_preservation_dir.join('2000_01_dissertations.temp/data/file.txt'), '')

      test_gsas_sync.instance_variable_set(:@downloaded_dirs, test_downloaded_dirs)
      test_gsas_sync.instance_variable_set(:@preservation_dir, temp_preservation_dir)
    end

    after do
      FileUtils.remove_entry(temp_preservation_dir)
    end

    describe '#rename_temp_dirs' do
      before do
        # TODO : remove redundant code?
        test_gsas_sync.instance_variable_set(:@downloaded_dirs, test_downloaded_dirs)
        test_gsas_sync.instance_variable_set(:@preservation_dir, temp_preservation_dir)
      end

      context 'in non-dry run mode' do
        it 'successfully renames files by removing .temp suffix and not changing location' do
          test_gsas_sync.rename_temp_dirs
          expect(File.directory?(temp_preservation_dir.join('2000_01_dissertations'))).to be(true)
          expect(File.directory?(temp_preservation_dir.join('2000_01_dissertations.temp'))).to be(false)
        end
      end

      context 'in dry run mode' do
        before do
          allow(GsasSync::Config).to receive(:dry_run).and_return(true)
        end

        it 'logs all' do
          expect(GsasSync::Logger).to receive(:log_all).once
          test_gsas_sync.rename_temp_dirs
        end

        it 'does not call FileUtils::mv method' do
          expect(FileUtils).not_to receive(:mv)
          test_gsas_sync.rename_temp_dirs
        end
      end
    end

    describe '#rm_temp_dirs' do
      it 'successfully deletes the .temp directory' do
        test_gsas_sync.rm_temp_dirs
        expect(File.exist?(temp_preservation_dir.join('2000_01_dissertations.temp'))).to be(false)
        expect(File.exist?(temp_preservation_dir.join('2000_01_dissertations'))).to be(false)
      end
    end

    describe '#download_files_to_temp_dir' do
      before do
        allow(test_gsas_sync).to receive(:verify_dissertations_directory_exists)
        allow(test_gsas_sync).to receive(:attempt_download)
      end

      it 'logs to progress on success' do
        expect(GsasSync::Logger).to receive(:progress)
        test_gsas_sync.download_files_to_temp_dir
      end
    end
  end

  describe '#attempt_download' do
    let(:sftp_client_double) { instance_double(SftpClient) }

    before do
      # test_gsas_sync.instance_variable_set(:@downloaded_dirs, test_downloaded_dirs)
      # test_gsas_sync.instance_variable_set(:@preservation_dir, temp_preservation_dir)

      # Mock GsasSync::SftpClient
      allow(SftpClient).to receive(:new).and_return(sftp_client_double)
      allow(sftp_client_double).to receive(:connect)
      allow(sftp_client_double).to receive(:uploads_dir?).and_return(true)
      allow(sftp_client_double).to receive(:dissertation_dirs?).and_return(true)
      allow(sftp_client_double).to receive(:check_dissertations_dir_already_exists)
      allow(sftp_client_double).to receive(:ls)
      allow(sftp_client_double).to receive(:dl_dissertation_dirs_to_temp).and_return(false)
      allow(sftp_client_double).to receive(:dissertation_dirs_array).and_return(test_downloaded_dirs)

      test_gsas_sync.instance_variable_set(:@sftp_client, sftp_client_double)
    end

    it 'downloads dissertation directories and sets @downloaded_dirs on success' do
      test_gsas_sync.attempt_download
      expect(test_gsas_sync.instance_variable_get(:@downloaded_dirs)).to eql(test_downloaded_dirs)
    end

    it 'raises SftpClientError if there is no uploads directory on the transfer server' do
      allow(sftp_client_double).to receive(:uploads_dir?).and_return(false)
      expect { test_gsas_sync.attempt_download }.to raise_error(GsasSync::Exceptions::SftpClientError)
    end

    it 'raises NoFilesToSync error if there are no directories to download from the transfer server' do
      allow(sftp_client_double).to receive(:dissertation_dirs?).and_return(false)
      expect { test_gsas_sync.attempt_download }.to raise_error(GsasSync::Exceptions::NoFilestoSync)
    end
  end

  describe '#verify_dissertations_directory_exists' do
    it 'raises a GsasError if the directory set as the download location on the local machine' do
      allow(File).to receive(:directory?).and_return(false)
      expect { test_gsas_sync.verify_dissertations_directory_exists }.to raise_error(GsasSync::Exceptions::GsasError)
    end
  end

  describe '#validate_downloaded_files' do
    let(:validator_double1) { instance_double(Validator) }
    let(:validator_double2) { instance_double(Validator) }

    before do
      allow(test_gsas_sync).to receive(:init_validators).and_return([validator_double1, validator_double2])
      allow(validator_double1).to receive(:run_validations).and_return(true)
      allow(validator_double2).to receive(:run_validations).and_return(true)
      allow(test_gsas_sync).to receive(:email_and_exit)
    end

    it 'returns true if each validator passes validations' do
      expect(test_gsas_sync.validate_downloaded_files).to be(true)
    end

    it 'returns false if at least one validator fails validations' do
      allow(validator_double1).to receive(:run_validations).and_return(false)
      expect(test_gsas_sync.validate_downloaded_files).to be(false)
    end
  end

  describe '#init_validators' do
    before do
      test_gsas_sync.instance_variable_set(:@downloaded_dirs, test_downloaded_dirs)
      allow(Validator).to receive(:new).and_return('test validator object')
    end

    it 'returns an array of validators, one for each @downlaoded_dirs element' do
      expect(test_gsas_sync.init_validators.length).to be(1)
    end
  end

  describe '#rm_remote_files' do
    let(:sftp_client_double) { instance_double(SftpClient) }

    before do
      test_gsas_sync.instance_variable_set(:@sftp_client, sftp_client_double)
      test_gsas_sync.instance_variable_set(:@downloaded_dirs, [*test_downloaded_dirs, 'another dir'])
      test_gsas_sync.instance_variable_set(:@uploads_dir, 'test uploads dir')

      allow(sftp_client_double).to receive(:connect)
      allow(sftp_client_double).to receive(:rm_recursive)
      allow(sftp_client_double).to receive(:disconnect)
    end

    context 'in dry run mode' do
      before do
        allow(GsasSync::Config).to receive(:dry_run).and_return(true)
      end

      it 'logs and exits' do
        expect(GsasSync::Logger).to receive(:log_all)
        test_gsas_sync.rm_remote_files
      end

      it 'does not call #rm_recursive' do
        expect(sftp_client_double).not_to receive(:rm_recursive)
        test_gsas_sync.rm_remote_files
      end
    end

    context 'in non-dry run mode' do
      it 'calls rm_recursive for each downloaded_dir' do
        expect(sftp_client_double).to receive(:rm_recursive).twice
        test_gsas_sync.rm_remote_files
      end
    end
  end

  describe '#email_and_exit' do # TODO: testing here
    before do
      allow(GsasSync::Logger).to receive(:close_progress_log_file)
      allow(GsasSync::Logger).to receive(:progress_log_append)
      allow(test_gsas_sync).to receive(:mail_client).and_return(mail_client_double)
      allow(mail_client_double).to receive(:make_and_send_email)
      allow(test_gsas_sync).to receive(:graceful_exit)
    end

    context 'in dry run mode' do
      before do
        allow(GsasSync::Config).to receive(:dry_run).and_return(true)
      end

      it 'logs that it is dry run to all' do
        expect(GsasSync::Logger).to receive(:log_all)
        test_gsas_sync.email_and_exit(success: true)
      end

      it 'gracefully exits' do
        expect(test_gsas_sync).to receive(:graceful_exit)
        test_gsas_sync.email_and_exit(success: true)
      end
    end

    context 'in non-dry run' do
      before do
        allow(test_gsas_sync).to receive(:rm_temp_dirs)
        allow(logger_double).to receive(:fatal)
        allow(GsasSync::Logger).to receive(:progress_log_append)
      end

      it 'logs all' do
        expect(GsasSync::Logger).to receive(:log_all).once
        test_gsas_sync.email_and_exit
      end

      it 'logs all if an error occurs sending email (including appending to log file)' do
        allow(mail_client_double).to receive(:make_and_send_email).and_raise(StandardError)
        expect(GsasSync::Logger).to receive(:progress_log_append).once
        test_gsas_sync.email_and_exit
      end

      it 'calls graceful_exit even if an error occurs' do
        allow(mail_client_double).to receive(:make_and_send_email).and_raise(StandardError)
        expect(test_gsas_sync).to receive(:graceful_exit).once
        test_gsas_sync.email_and_exit
      end

      it 'closes the progress log file' do
        expect(GsasSync::Logger).to receive(:close_progress_log_file)
        test_gsas_sync.email_and_exit
      end
    end
  end

  describe '#graceful_exit' do
    let(:sftp_client_double) { instance_double(SftpClient) }

    before do
      allow(GsasSync::Logger).to receive(:close_progress_log_file)
      test_gsas_sync.instance_variable_set(:@sftp_client, sftp_client_double)
      allow(sftp_client_double).to receive(:disconnect)
      allow(sftp_client_double).to receive(:nil?).and_return(false)
      allow(sftp_client_double).to receive(:closed?).and_return(false)
      allow(test_gsas_sync).to receive(:exit)
    end

    it 'calls exit on success' do
      expect(test_gsas_sync).to receive(:exit).once
      test_gsas_sync.graceful_exit
    end

    it 'does not disconnect if the sftp client is nil' do
      allow(sftp_client_double).to receive(:nil?).and_return(true)
      expect(sftp_client_double).not_to receive(:disconnect)
      test_gsas_sync.graceful_exit
      test_gsas_sync.graceful_exit
    end

    it 'does not disconnect if the sftp client has already closed the connection' do
      allow(sftp_client_double).to receive(:closed?).and_return(true)
      expect(sftp_client_double).not_to receive(:disconnect)
      test_gsas_sync.graceful_exit
    end
  end

  describe '#log_summary' do
    before do
      allow(GsasSync::Logger).to receive(:progress)
      test_gsas_sync.instance_variable_set(:@downloaded_dirs, test_downloaded_dirs)
    end

    context 'in dry run mode' do
      before do
        allow(GsasSync::Config).to receive(:dry_run).and_return(true)
      end

      it 'logs the temporary directory contents' do
        expect(GsasSync::Logger).to receive(:progress_log_dir_contents).with('path/to/storage/directory/2000_01_dissertations.temp') # rubocop:disable Layout/LineLength
        test_gsas_sync.log_summary
      end
    end

    context 'in non-dry run mode' do
      it 'logs the dissertation directory contents' do
        expect(GsasSync::Logger).to receive(:progress_log_dir_contents).with('path/to/storage/directory/2000_01_dissertations') # rubocop:disable Layout/LineLength
        test_gsas_sync.log_summary
      end
    end
  end
end

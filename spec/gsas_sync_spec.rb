# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GsasSync do
  # GLOBAL TESTING OBJECTS (ALL OTHERS SCOPED TO EXAMPLE GROUPS OR EXAMPLES)
  let(:logger_double) { instance_double(Logger) }
  let(:test_gsas_sync) { described_class.new }

  test_storage_config_hash = { 'directory' => 'path/to/storage/directory' }

  before do
    allow(GsasSync::Logger).to receive(:stdout_logger).and_return(logger_double)
    allow(logger_double).to receive(:info)
    allow(logger_double).to receive(:debug)

    allow(GsasSync::Config).to receive(:storage).and_return(test_storage_config_hash)
    allow(GsasSync::Config).to receive(:dry_run).and_return(false) # Override in example groups for dry run testing
  end

  describe '#initialize' do
    it 'sets instance variables' do
      expect(test_gsas_sync.instance_variable_get(:@preservatio_dir)).to be(test_storage_config_hash['directory'])
      expect(test_gsas_sync.instance_variable_get(:@uplaods_dir)).to be('uploads')
      expect(test_gsas_sync.instance_variable_get(:@downloaded_dirs)).to match_array([])
    end
  end

  describe '#rename_temp_dirs' do
  end

  describe '#rm_temp_dirs' do
  end

  describe '#download_files_to_temp_dir' do
  end

  describe '#attempt_download' do
  end

  describe '#verify_dissertations_directory_exists' do
  end

  describe '#validate_downloaded_files' do
  end

  describe '#init_validators' do
  end

  describe '#rm_remote_files' do
  end

  describe '#email_and_exit_failure' do
  end

  describe '#send_failure_email' do
  end

  describe '#email_and_exist_success' do
  end

  describe '#send_success_email' do
  end

  describe '#graceful_exit' do
  end

  describe '#log_summary' do
  end
end

# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Validator do
  # IN THESE TESTS:
  #  - WE USE THE DATE-PREFIX 2000_01
  #  - WE ASSUME THERE IS ONLY ONE file.txt IN data/, AND IT IS EMPTY #  - WE ASSUME THE MANIFEST FILE USES SHA256
  empty_file_checksum = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
  empty_file_checksum_diff_cases = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  empty_file_checksum_md5 = 'd41d8cd98f00b204e9800998ecf8427e'

  let(:logger_double) { instance_double(Logger) }
  let(:base_dir) { Pathname.new(Dir.mktmpdir('2000_01_dissertations.temp')) }
  let(:test_date_prefix_str) { '2000_01' }
  let(:num_nested_items) { 5 }
  let(:test_validator) { described_class.new(base_dir) }
  let(:expected_test_manifest_hash) { { base_dir.join('data/file.txt').to_s => empty_file_checksum } }
  let(:expected_test_manifest_hash_diff_cases) { { base_dir.join('data/file.txt').to_s => empty_file_checksum_diff_cases } } # rubocop:disable Layout/LineLength
  let(:expected_test_manifest_hash_md5) { { base_dir.join('data/file.txt').to_s => empty_file_checksum_md5 } }
  let(:test_downloaded_files_array) { [base_dir.join('data/file.txt').to_s] }
  let(:digest_class_double) { class_double(Digest::SHA256) }
  let(:digest_class_double_md5) { class_double(Digest::MD5) }

  before do
    # Mock logging
    allow(GsasSync::Logger).to receive(:stdout_logger).and_return(logger_double)
    allow(GsasSync::Logger).to receive(:log_all)
    allow(GsasSync::Logger).to receive(:log_all_warn)
    allow(GsasSync::Logger).to receive(:log_all_error)
    allow(logger_double).to receive(:debug)
    allow(logger_double).to receive(:info)

    # # Mock this method in general
    # allow(test_validator).to receive(:log_validation_result)

    # Create temporary files for validation
    File.write(base_dir.join('2000_01_items.csv'), 'item data')
    File.write(base_dir.join('2000_01_assets.csv'), 'asset data')
    FileUtils.mkdir(base_dir.join('data'))
    File.write(base_dir.join('data/file.txt'), '')
    File.write(base_dir.join('manifest-sha256.txt'), "#{empty_file_checksum} ./data/file.txt")
  end

  after do
    # Clean up temp files + directory
    FileUtils.remove_entry(base_dir)
  end

  describe '#initialize' do
    it 'sets @parent instance variable and nothing else' do
    end
  end

  describe '#run_validations' do
    it 'calls each validation method' do
      allow(test_validator).to receive(:all_required_files_present?)
      allow(test_validator).to receive(:no_undesirable_characters_in_file_paths?)
      allow(test_validator).to receive(:all_accounted_for_in_manifest?)
      allow(test_validator).to receive(:valid_checksums?)

      expect(test_validator).to receive(:all_required_files_present?)
      expect(test_validator).to receive(:no_undesirable_characters_in_file_paths?)
      expect(test_validator).to receive(:all_accounted_for_in_manifest?)
      expect(test_validator).to receive(:valid_checksums?)
      test_validator.run_validations
    end

    it 'returns true if all four validations pass' do
      allow(test_validator).to receive(:all_required_files_present?).and_return true
      allow(test_validator).to receive(:no_undesirable_characters_in_file_paths?).and_return true
      allow(test_validator).to receive(:all_accounted_for_in_manifest?).and_return true
      allow(test_validator).to receive(:valid_checksums?).and_return true

      expect(test_validator.run_validations).to be(true)
    end

    it 'returns false if any of the four validations fail' do
      allow(test_validator).to receive(:all_required_files_present?).and_return true
      allow(test_validator).to receive(:no_undesirable_characters_in_file_paths?).and_return true
      allow(test_validator).to receive(:all_accounted_for_in_manifest?).and_return true
      allow(test_validator).to receive(:valid_checksums?).and_return false # THIS ONE FALSE!

      expect(test_validator.run_validations).to be(false)
    end
  end

  describe '#all_required_files_present?' do
    before do
      allow(test_validator).to receive(:valid_manifest_file?).and_return(true)
      allow(test_validator).to receive(:valid_items_csv?).and_return(true)
      allow(test_validator).to receive(:valid_assets_csv?).and_return(true)
      allow(test_validator).to receive(:log_validation_result)
    end

    it 'sets the @date_prefix_str instance variable' do
      test_validator.all_required_files_present?

      expect(test_validator.instance_variable_get(:@date_prefix_str)).to eql(test_date_prefix_str)
    end

    it 'returns true if all sub-tests return true' do
      expect(test_validator.all_required_files_present?).to be(true)
    end

    it 'returns false if any of the sub-tests return false' do
      allow(test_validator).to receive(:valid_assets_csv?).and_return(false) # THIS ONE FALSE!

      expect(test_validator.all_required_files_present?).to be(false)
    end

    it 'logs the result no matter what' do
      expect(test_validator).to receive(:log_validation_result)

      test_validator.all_required_files_present?
    end
  end

  describe '#valid_manifest_file?' do
    before do
      test_validator.instance_variable_set(:@manifest_filename, 'manifest-sha256.txt')
      allow(test_validator).to receive(:find_manifest_file!)
      allow(test_validator).to receive(:init_manifest_digest)
    end

    it 'returns true if the manifest file is validated' do
      expect(test_validator.valid_manifest_file?).to be(true)
    end

    context 'if the checksum algorithm is unexpected' do
      before do
        test_validator.instance_variable_set(:@manifest_filename, 'manifest-BADALGO.txt')
      end

      it 'returns false' do
        expect(test_validator.valid_manifest_file?).to be(false)
      end

      it 'logs any exception raised' do
        expect(GsasSync::Logger).to receive(:log_all_error)

        test_validator.valid_manifest_file?
      end
    end

    context 'if the checksum algorithm is missing' do
      before do
        test_validator.instance_variable_set(:@manifest_filename, 'manifest-.txt')
      end

      it 'returns false' do
        expect(test_validator.valid_manifest_file?).to be(false)
      end

      it 'logs any exception raised' do
        expect(GsasSync::Logger).to receive(:log_all_error)

        test_validator.valid_manifest_file?
      end
    end

    context 'if an error occurs in #find_manifest_file!' do
      before do
        allow(test_validator).to receive(:find_manifest_file!).and_raise(StandardError)
      end

      it 'logs the error' do
        expect(GsasSync::Logger).to receive(:log_all_error)
        test_validator.valid_manifest_file?
      end

      it 'returns false' do
        expect(test_validator.valid_manifest_file?).to be(false)
      end
    end

    context 'if an error occurs in #init_manifest_digest' do
      before do
        allow(test_validator).to receive(:init_manifest_digest).and_raise(StandardError)
      end

      it 'logs the error' do
        expect(GsasSync::Logger).to receive(:log_all_error)
        test_validator.valid_manifest_file?
      end

      it 'returns false' do
        expect(test_validator.valid_manifest_file?).to be(false)
      end
    end
  end

  describe '#find_manifest_file!' do
    context 'if one, validly-named manifest file is present' do
      it 'sets the @manifest_filename instance variable' do
        test_validator.find_manifest_file!

        expect(test_validator.instance_variable_get(:@manifest_filename)).to eql('manifest-sha256.txt')
      end
    end

    context 'if multiple, validly-named manifest files are present' do
      before do
        File.write(base_dir.join('manifest-md5.txt'), "#{empty_file_checksum} data/file.txt")
      end

      it 'raises a ValidationError' do
        expect { test_validator.find_manifest_file! }.to raise_error(GsasSync::Exceptions::ValidationError)
      end

      it 'does not set the @manifest_filename instance variable' do
        begin
          test_validator.find_manifest_file!
        rescue GsasSync::Exceptions::ValidationError # rubocop:disable Lint/SuppressedException
        end
        expect(test_validator.instance_variable_get(:@manifest_filename)).to be('')
      end
    end

    context 'if no validly-named manifests file is present' do
      before do
        File.delete(base_dir.join('manifest-sha256.txt'))
      end

      it 'raises a ValidationError' do
        expect { test_validator.find_manifest_file! }.to raise_error(GsasSync::Exceptions::ValidationError)
      end

      it 'does not set the @manifest_filename instance variable' do
        begin
          test_validator.find_manifest_file!
        rescue GsasSync::Exceptions::ValidationError # rubocop:disable Lint/SuppressedException
        end
        expect(test_validator.instance_variable_get(:@manifest_filename)).to be('')
      end
    end
  end

  describe '#init_manifest_digest' do
    it 'sets the @digest_class instance variable when given a valid algorithm' do
      test_validator.init_manifest_digest('sha256')
      expect(test_validator.instance_variable_get(:@digest_class)).to eql(Digest::SHA256)
    end

    it 'raises an exception when given an invalid algorithm' do
      expect { test_validator.init_manifest_digest }.to raise_error(StandardError)
    end
  end

  describe '#valid_items_csv?' do
    it 'returns true if the expected items csv file exists' do
      test_validator.instance_variable_set(:@date_prefix_str, test_date_prefix_str)
      expect(test_validator.valid_items_csv?).to be(true)
    end

    context 'if the expected items csv file does not exists' do
      before do
        test_validator.instance_variable_set(:@date_prefix_str, '3333_01')
      end

      it 'returns false' do
        expect(test_validator.valid_items_csv?).to be(false)
      end

      it 'logs to all that the file is not present' do
        expect(GsasSync::Logger).to receive(:log_all_warn)
        test_validator.valid_items_csv?
      end
    end
  end

  describe '#valid_assets_csv?' do
    it 'returns true if the expected assets csv file exists' do
      test_validator.instance_variable_set(:@date_prefix_str, test_date_prefix_str)
      expect(test_validator.valid_assets_csv?).to be(true)
    end

    context 'if the expected assets csv file does not exists' do
      before do
        test_validator.instance_variable_set(:@date_prefix_str, '3333_01')
      end

      it 'returns false' do
        expect(test_validator.valid_assets_csv?).to be(false)
      end

      it 'logs to all that the file is not present' do
        expect(GsasSync::Logger).to receive(:log_all_warn)
        test_validator.valid_assets_csv?
      end
    end
  end

  describe '#no_undesirable_characters_in_file_paths?' do
    context 'if the result is valid' do
      before do
        expect(test_validator).to receive(:log_validation_result)
        allow(test_validator).to receive(:valid_file_paths_recursive).and_return(true)
      end

      it 'logs the result' do
        test_validator.no_undesirable_characters_in_file_paths?
      end

      it 'returns true' do
        expect(test_validator.no_undesirable_characters_in_file_paths?).to be(true)
      end
    end

    context 'if the result is not valid' do
      before do
        allow(test_validator).to receive(:valid_file_paths_recursive).and_return(false)
      end

      it 'logs the result' do
        expect(test_validator).to receive(:log_validation_result)
        test_validator.no_undesirable_characters_in_file_paths?
      end

      it 'returns false' do
        expect(test_validator.no_undesirable_characters_in_file_paths?).to be(false)
      end
    end
  end

  describe '#valid_file_paths_recursive' do
    before do
      allow(test_validator).to receive(:log_validated_filepath)
    end

    context 'if given a directory of valid filepaths' do
      it 'returns true' do
        expect(test_validator.valid_file_paths_recursive).to be(true)
      end

      it 'logs each directory and file' do
        num_items = num_nested_items + 1 # we also validate the parent directory
        expect(test_validator).to receive(:log_validated_filepath).exactly(num_items).times
        test_validator.valid_file_paths_recursive
      end
    end

    context 'if given a directory containing an invalid filepath nested within' do
      before do
        File.write(base_dir.join('我能.我能'), '') # Add a file with bad characters
      end

      it 'returns false' do
        expect(test_validator.valid_file_paths_recursive).to be(false)
      end

      it 'logs each directory and file, even after reaching the invalid file' do
        num_items = num_nested_items + 1 + 1 # we also validate the parent directory and the 'bad' file
        expect(test_validator).to receive(:log_validated_filepath).exactly(num_items).times
        test_validator.valid_file_paths_recursive
      end
    end
  end

  describe '#log_validated_filepath' do
    let(:test_fp) { Pathname.new('test_file') }

    it 'only logs to standard out if valid is true' do
      valid = true
      test_object = test_validator # Ignore the calls to logger during initialization
      expect(GsasSync::Logger).to receive(:stdout_logger)
      expect(logger_double).to receive(:debug)
      expect(GsasSync::Logger).not_to receive(:log_all_warn)

      test_object.log_validated_filepath(test_fp, valid)
    end

    it 'logs all as warning if valid is false' do
      valid = false
      test_object = test_validator # Ignore the calls to logger during initialization
      expect(GsasSync::Logger).not_to receive(:stdout_logger)
      expect(logger_double).not_to receive(:debug)
      expect(GsasSync::Logger).to receive(:log_all_warn)

      test_object.log_validated_filepath(test_fp, valid)
    end
  end

  # THIS METHOD (AND RELATED HELPER METHODS) HAS BEEN HEAVILY REFACTORED!
  describe '#all_accounted_for_in_manifest?' do
    before do
      allow(test_validator).to receive(:valid_manifest_and_digest_instance_variables?).and_return(true)
      allow(test_validator).to receive(:build_manifest_hash)
      allow(test_validator).to receive(:files_in_manifest_exist?).and_return(true)
      allow(test_validator).to receive(:all_downloaded_files_in_manifest?).and_return(true)
      allow(test_validator).to receive(:log_validation_result)
      test_validator.instance_variable_set(:@manifest_filename, 'manifest-sha256.txt')
    end

    it 'returns false if #valid_manifest_and_digest_instance_variables returns false' do
      allow(test_validator).to receive(:valid_manifest_and_digest_instance_variables?).and_return(false)
      expect(test_validator.all_accounted_for_in_manifest?).to be(false)
    end

    it 'returns does not perform validations if #valid_manifest_and_digest_instance_variables returns false' do
      allow(test_validator).to receive(:valid_manifest_and_digest_instance_variables?).and_return(false)
      expect(test_validator).not_to receive(:files_in_manifest_exist?)
      expect(test_validator).not_to receive(:all_downloaded_files_in_manifest?)
    end
  end

  describe '#build_manifest_hash' do
    it 'correctly builds a hash map from a valid manifest file' do
      test_validator.instance_variable_set(:@manifest_hash, {})
      test_validator.instance_variable_set(:@manifest_filename, 'manifest-sha256.txt')
      test_validator.build_manifest_hash

      expect(test_validator.instance_variable_get(:@manifest_hash)).to eq(expected_test_manifest_hash)
    end
  end

  describe '#files_in_manifest_exist?' do
    context 'given a manifest with all existing files' do
      it 'returns true' do
        test_validator.instance_variable_set(:@manifest_hash, expected_test_manifest_hash)

        expect(test_validator.files_in_manifest_exist?).to be(true)
      end
    end

    context 'given a manifest with non-existent files' do
      before do
        test_validator.instance_variable_set(:@manifest_hash, { 'non/existent/file.txt' => 'aaaa' })
      end

      it 'returns false' do
        expect(test_validator.files_in_manifest_exist?).to be(false)
      end

      it 'logs a warning to all' do
        expect(GsasSync::Logger).to receive(:log_all_warn)
        test_validator.files_in_manifest_exist?
      end

      it 'deletes the missing file from the @manifest_hash object' do
        test_validator.files_in_manifest_exist?
        expect(test_validator.instance_variable_get(:@manifest_hash)).to eq({})
      end
    end
  end

  describe '#all_downloaded_files_in_manifest?' do
    before do
      test_validator.instance_variable_set(:@manifest_hash, expected_test_manifest_hash)
      allow(test_validator).to receive(:recursive_files_array).and_return(test_downloaded_files_array)
    end

    it 'returns true if all downloaded files are in the @manifest_hash' do
      expect(test_validator.all_downloaded_files_in_manifest?).to be(true)
    end

    context 'if a file is missing from the manifest' do
      before do
        array_with_extra_file = [*test_downloaded_files_array, 'an/extra/file/not/in/manifest.txt']
        allow(test_validator).to receive(:recursive_files_array).and_return(array_with_extra_file)
      end

      it 'returns false' do
        expect(test_validator.all_downloaded_files_in_manifest?).to be(false)
      end

      it 'logs a warning to all' do
        expect(GsasSync::Logger).to receive(:log_all_warn)
        test_validator.all_downloaded_files_in_manifest?
      end
    end
  end

  describe '#recursive_files_array' do
    before do
      # test_validator.instance_variable_set(:@parent, base_dir)
      allow(test_validator).to receive(:recursive_files_array).and_call_original
      allow(test_validator).to receive(:metadata_file?).with('2000_01_assets.csv').and_return(true)
      allow(test_validator).to receive(:metadata_file?).with('2000_01_items.csv').and_return(true)
      allow(test_validator).to receive(:metadata_file?).with('manifest-sha256.txt').and_return(true)
      allow(test_validator).to receive(:metadata_file?).with('file.txt').and_return(false)
    end

    it 'builds the expected array' do
      expect(test_validator.recursive_files_array(base_dir)).to eql(test_downloaded_files_array)
    end

    it 'does not add metadata files' do
      result = test_validator.recursive_files_array
      expect(result).not_to include(base_dir.join('2000_01_assets.csv'))
      expect(result).not_to include(base_dir.join('2000_01_items.csv'))
      expect(result).not_to include(base_dir.join('manifest-sha256.txt'))
    end

    it 'calls itself recursively on non-empty directories' do
      # expect(test_validator).to receive(:recursive_files_array)
      test_validator.recursive_files_array

      expect(test_validator).to have_received(:recursive_files_array).with(base_dir.join('data'))
      expect(test_validator).to have_received(:recursive_files_array).exactly(2).times
    end
  end

  describe '#metadata_file?' do
    before do
      test_validator.instance_variable_set(:@date_prefix_str, test_date_prefix_str)
      test_validator.instance_variable_set(:@manifest_filename, 'manifest-sha256.txt')
    end

    it 'returns true if the file is an items_csv' do
      expect(test_validator.metadata_file?('2000_01_items.csv')).to be(true)
    end

    it 'returns true if the file is an assets_csv' do
      expect(test_validator.metadata_file?('2000_01_assets.csv')).to be(true)
    end

    it 'returns true if the file is manifest file' do
      expect(test_validator.metadata_file?('manifest-sha256.txt')).to be(true)
    end

    it 'returns false if the file is anything else' do
      expect(test_validator.metadata_file?('some_file.txt')).to be(false)
    end
  end

  describe '#valid_manifest_and_digest_instance_variables?' do
    it 'returns true if both instance variables are not nil/empty' do
      test_validator.instance_variable_set(:@manifest_filename, 'manifest-sha256.txt')
      test_validator.instance_variable_set(:@digest_class, Digest::SHA256)

      expect(test_validator.valid_manifest_and_digest_instance_variables?).to be(true)
    end

    context 'invalid @manifest_filename' do
      before do
        test_validator.instance_variable_set(:@manifest_filename, '')
        test_validator.instance_variable_set(:@digest_class, nil)
      end

      it 'returns false' do
        expect(test_validator.valid_manifest_and_digest_instance_variables?).to be(false)
      end

      it 'logs a warning to all' do
        test_validator.valid_manifest_and_digest_instance_variables?
        expect(GsasSync::Logger).to have_received(:log_all_warn)
      end

      # TODO: HERE : CAN I TEST THIS? MAYBE NEED TO SPY ON THAT INSTANCE VARIABLE
      it 'does not check the @digest_class value' do
        # digest_class_double = instance_double(Digest::SHA256)
        allow(digest_class_double).to receive(:nil?)
        test_validator.instance_variable_set(:@digest_class, digest_class_double)
        test_validator.valid_manifest_and_digest_instance_variables?
        expect(digest_class_double).not_to have_received(:nil?)
      end
    end

    context 'valid @manifest_filename but invalid @digest_class' do
      before do
        test_validator.instance_variable_set(:@manifest_filename, 'manifest-sha111.txt')
        test_validator.instance_variable_set(:@digest_class, nil)
      end

      it 'returns false' do
        expect(test_validator.valid_manifest_and_digest_instance_variables?).to be(false)
      end

      it 'logs a warning to all' do
        expect(GsasSync::Logger).to receive(:log_all_warn)
        test_validator.valid_manifest_and_digest_instance_variables?
      end

      it 'checks the @digest_class value' do
        # digest_class_double = instance_double(Digest::SHA256)
        allow(digest_class_double).to receive(:nil?)
        test_validator.instance_variable_set(:@digest_class, digest_class_double)
        test_validator.valid_manifest_and_digest_instance_variables?
        expect(digest_class_double).to have_received(:nil?)
      end
    end
  end

  describe '#valid_checksums?' do
    let(:digest_instance_double) { instance_double(Digest::Instance) }

    context 'if #valid_manifest_and_digest_instance_variables? returns false' do
      before do
        allow(test_validator).to receive(:valid_manifest_and_digest_instance_variables?).and_return(false)
      end

      it 'returns false' do
        expect(test_validator.valid_checksums?).to be(false)
      end

      it 'logs a warning to all' do
        expect(GsasSync::Logger).to receive(:log_all_warn).once
        test_validator.valid_checksums?
      end
    end

    context 'with a successful transfer' do
      before do
        allow(test_validator).to receive(:valid_manifest_and_digest_instance_variables?).and_return(true)
        allow(test_validator).to receive(:log_validation_result)
        test_validator.instance_variable_set(:@manifest_hash, expected_test_manifest_hash)
        # test_validator.instance_variable_set(:@digest_class, digest_class_double)
        test_validator.instance_variable_set(:@digest_class, digest_class_double)
        allow(digest_class_double).to receive(:file).and_return(digest_instance_double)
        allow(digest_instance_double).to receive(:hexdigest).and_return(empty_file_checksum)
      end

      it 'returns true' do
        expect(test_validator.valid_checksums?).to be(true)
      end

      it 'returns true even if the checksums use different cases' do
        test_validator.instance_variable_set(:@manifest_hash, expected_test_manifest_hash_diff_cases)
        expect(test_validator.valid_checksums?).to be(true)
      end

      it 'computes the checksum for each file in the @manifest_hash' do
        expect(digest_instance_double).to receive(:hexdigest).once
        test_validator.valid_checksums?
      end
    end
  end
end

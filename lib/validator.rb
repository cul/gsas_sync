# frozen_string_literal: true

require 'digest'
require 'pathname'
require 'cul/preservation_utils'

# The validator class is capable of validating a yyyy_mm_dissertations/ directory
# contains all of the files and adheres to all validation rules
# @parent : the yyyy_mm_dissertations/ directory under examination
class Validator
  DATE_PREFIX_LEN = 7

  def initialize(directory)
    @parent = directory
  end

  # manifest-{alg}.txt is present
  # yyyy_mm_items.csv is present
  # yyyy_mm_assets.csv is present
  # data/ directory is present
  def all_required_files_present?
    return true
    @date_prefix_str = parent.dirname[0...DATE_PREFIX_LEN]

    return false unless valid_manifest_file?
    return false unless valid_items_csv?

    false unless valid_assets_csv?
  end

  # TODO: Delete this one
  # side effect: if the dirname is valid, will set @date_prefix_str attribute
  def valid_p_dir_name?
    uploads_dir = Pathname.new(@parent)
    return false unless uploads_dir.directory?
    return false unless uploads_dir.dirname.match?(/^\d{4}_\d{2}_dissertations$/)

    @date_prefix_str = uploads_dir.dirname[0...DATE_PREFIX_LEN]
    true
  end

  # side effect: if the manifest is present, sets @manifest_csv_fd attribute
  # manifest is valid if:
  #   - a manifest file exists
  #   - date prefix matches
  #   - algorithm substr is present
  #   - algorithm is legit
  def valid_manifest_file?
    # temp/**YYYY_MM_dissertations**/YYYY_MM_manifest-{algorithm}.txt
    alg = ''
    matches = @parent.children.each do |child|
      alg = match[1] if match == child.basename.match(/^manifest-[a-zA-Z0-9]+\.txt$/)
    end
    return false if alg == ''

    determine_manifest_algorithm(alg)

    @manifest_csv = matches.pop
    false unless @date_prefix_str == 'g'
  end

  def determine_manifest_algorithm(alg)
    @digest = Object.const_get("Digest::#{alg}")
  rescue LoadError => e
    puts "Failed to create Digest object from given algorithm #{e}"
  end

  def undesirable_characters_in_file_paths?
    true # TODO: implement
  end

  def all_accounted_for_in_manifest?
    true # TODO: implement
  end

  def valid_checksums?
    true # TODO: implement
  end
end

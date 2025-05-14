# frozen_string_literal: true

module ErrorHandling
  # attr_accessor :filepath, :log_file
  DEF_DIR = 'logs'
  DEF_FN = 'error_logs.log'

  # Opens and returns the elog file object
  def self.init(logs_dir = DEF_DIR, filename = DEF_FN, logger)
    filepath = "#{logs_dir}/#{filename}"
    logger.info "Initializing Error Logs at #{filepath}"
    begin
      File.mkdir(logs_dir) unless File.directory?(logs_dir)
      File.delete(filepath) if File.file?(filepath)
      File.open(filepath, 'w')
    rescue StandardError => e
      logger.error("Unable to create #{filepath}")
      logger.error(e)
      if filepath == "#{DEF_DIR}/#{DEF_FN}"
        logger.fatal('Default options were used -- fatal. Exiting...')
        exit(1)
      end
      begin
        logger.debug("Attempting to create error logs with defaults (#{DEF_DIR}/#{DEF_FN})...")
        File.mkdir(DEF_DIR) unless File.directory?(DEF_DIR)
        File.delete(DEF_FN) if File.file?(DEF_FN)
        File.open("#{DEF_DIR}/#{DEF_FN}", 'w')
      rescue StandardError
        logger.fatal("Unable to create #{filepath}")
        logger.fatal(e)
        exit(1)
      end
    end
  end

  def self.elog_msg(msg)
    "#{GsasSync::TERM_PREFIX} #{msg}\n"
  end
end

# frozen_string_literal: true

module GsasSync::Exceptions
  class GsasError < StandardError; end

  class NoFilestoSync < GsasError; end
  class SftpClientError < GsasError; end
  class ValidationError < GsasError; end
  class EmailError < GsasError; end
end

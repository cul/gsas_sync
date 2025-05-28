# frozen_string_literal: true

class EmailClient
  FAILURE_SUBJECT = 'Failure: Gsas Sync process could not complete the file transfer'
  FAILURE_BODY = 'The Gsas Sync process failed to complete the transfer process. A log file has been attached detailing what occurred. Please address any validation errors and contact the DLST to attempt the transfer again.'

  def initialize(config)
    @server = config['mail_server']['host']
    @port = config['mail_server']['port']
    @sender = config['mail_server']['sender_address']
    @recipients = config['mail_server']['recipients']
    @log_file = config['logs']['location']
    Mail.defaults do
      delivery_method :smtp, address: 'smtp.library.columbia.edu', port: 25 # @server, port: @port
    end
  end

  def send_failure_email_all
    subject = FAILURE_SUBJECT
    body = FAILURE_BODY
    @recipients.foreach { |email| send_failure_email(email, subject, body) }
  end

  def send_failure_email(recipient, subject, body)
    sender = @sender # lexical scope needed for Mail.deliver block; use local variables
    log_file = @log_file
    Mail.deliver do
      from sender
      to recipient
      subject subject
      body body
      add_file "#{FileUtils.pwd}/#{log_file}"
    end
    # TODO: log
  end
end

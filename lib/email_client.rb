# frozen_string_literal: true

class EmailClient
  def initialize(config)
    @server = config['mail_server']['host']
    puts @server
    Mail.defaults do
      delivery_method :smtp, address: 'smtp.library.columbia.edu', port: 25
    end
  end

  def send_test_email
    Mail.deliver do
      from 'bradleygoldsmith14@gmail.com'
      to 'bradleygoldsmith14@gmail.com'
      subject 'Test'
      body 'Test'
      # add_file "#{FileUtils.pwd}/logs/progress.log"
    end
  end
end

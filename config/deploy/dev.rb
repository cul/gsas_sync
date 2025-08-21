# frozen_string_literal: true

set :stage, :dev
server 'diglib-service-prod1.cul.columbia.edu', user: fetch(:remote_user)

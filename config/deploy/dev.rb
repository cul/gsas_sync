# frozen_string_literal: true

set :stage, :dev
set :branch, 'LDPD-451'
server 'diglib-service-prod1.cul.columbia.edu', user: fetch(:remote_user), roles: %w[app]

# frozen_string_literal: true

set :stage, :dev
server 'diglib-service-prod1.cul.columbia.edu', user: fetch(:remote_user), roles: %w[production_app]

ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

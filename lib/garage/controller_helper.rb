require 'doorkeeper'
require 'rack-accept-default'
require 'http_status_exceptions'

module Garage
  module ControllerHelper
    extend ActiveSupport::Concern
    included do
      use Rack::AcceptDefault
      include ::Doorkeeper::Helpers::Filter
      doorkeeper_for :all

      # TODO current_user

      if defined?(CanCan)
        rescue_from CanCan::AccessDenied do |exception|
          render :json => { :error => exception.message }, :status => :forbidden
        end
      end

      before_filter HypermediaResponder

      respond_to :json # , :msgpack
      self.responder = Garage::AppResponder

=begin
      before_filter Garage::BackdoorKeeper
      def doorkeeper_token
        @token ||= Garage::BackdoorKeeper.get_token(request.env) || super
      end
=end
    end

    def authorized_application
      doorkeeper_token.application if doorkeeper_token
    end

    def current_resource_owner
      raise "Your ApplicationController needs to implement current_resource_owner!"
    end

    # Hack: returns if the current resource is the same as the requester
    def request_by?(resource)
      true # FIXME
      # resource.is_a?(User) && current_resource_owner.try(:id) == resource.id
    end

    # Public: returns if the current request includes the given OAuth scope
    def has_scope?(scope)
      doorkeeper_token && doorkeeper_token.scopes.include?(scope)
    end

    def resource_owner_id
      doorkeeper_token.resource_owner_id if doorkeeper_token
    end

    def require_authentication
      head 401 unless current_resource_owner
    end

    attr_accessor :representation, :field_selector

  private

    # TODO move this to ::Utils

    # Private: extract date time range query from query parameters
    # Treat `from` and `to` as aliases for `gte` and `lte` respectively
    def extract_datetime_query(prefix)
      query = {}
      {:from => :gte, :to => :lte, :gt => nil, :lt => nil, :gte => nil, :lte => nil}.each do |key, as|
        k = "#{prefix}.#{key}"
        if params.has_key?(k)
          query[as || key] = fuzzy_parse(params[k]) or raise HTTPStatus::BadRequest, "Can't parse datetime #{params[k]}"
        end
      end
      query if query.size > 0
    end

    def fuzzy_parse(date)
      if date.is_a?(Numeric) || /^\d+$/ === date
        Time.zone.at(date.to_i)
      else
        Time.zone.parse(date)
      end
    rescue ArgumentError
      nil
    end
  end
end
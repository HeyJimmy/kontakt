require 'kontakt/rails/controller/url_rewriting'
require 'kontakt/rails/controller/redirects'

module Kontakt
  module Rails

    # Rails application controller extension
    module Controller
      def self.included(base)
        base.class_eval do
          include Kontakt::Rails::Controller::UrlRewriting
          include Kontakt::Rails::Controller::Redirects

          # Fix cookie permission issue in IE
          before_filter :normal_cookies_for_ie_in_iframes!

          helper_method(:kontakt, :vk_params, :vk_signed_params, :params_without_vk_data,
            :current_vk_user, :vk_canvas?
          )

          helper Kontakt::Rails::Helpers
        end
      end

      protected

      KONTAKT_PARAM_NAMES = %w{api_url api_id user_id sid secret group_id viewer_id viewer_type is_app_user is_secure
        auth_key language parent_language api_result api_settings referrer access_token hash lc_name ad_info}

      RAILS_PARAMS = %w{controller action}

      # Accessor to current application config. Override it in your controller
      # if you need multi-application support or per-request configuration selection.
      def kontakt
        Kontakt::Config.default
      end

      # A hash of params passed to this action, excluding secure information passed by Vkontakte
      def params_without_vk_data
        params.except(*(KONTAKT_PARAM_NAMES))
      end

      # params coming directly from Vkontakte
      def vk_params
        params.except(*RAILS_PARAMS)
      end

      # encrypted vkontakte params
      def vk_signed_params
        if vk_params['sid'].present?
          encrypt(vk_params)
        else
          request.env["HTTP_SIGNED_PARAMS"] || request.params['signed_params'] || flash[:signed_params]
        end
      end

      # Accessor to current vkontakte user. Returns instance of Kontakt::User
      def current_vk_user
        @current_vk_user ||= fetch_current_vk_user
      end

      # Did the request come from canvas app
      def vk_canvas?
        vk_params['sid'].present? || request.env['HTTP_SIGNED_PARAMS'].present? || flash[:signed_params].present?
      end

      private

      def fetch_current_vk_user
        Kontakt::User.from_vk_params(kontakt, vk_params['sid'].present? ? vk_params : vk_signed_params)
      end

      def encrypt(params)
        encryptor = ActiveSupport::MessageEncryptor.new("secret_key_#{kontakt.app_secret}")

        encryptor.encrypt_and_sign(params)
      end

      def decrypt(encrypted_params)
        encryptor = ActiveSupport::MessageEncryptor.new("secret_key_#{kontakt.app_secret}")

        encryptor.decrypt_and_verify(encrypted_params)
      rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
        nil
      end
    end
  end
end
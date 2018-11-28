# frozen_string_literal: true

Faraday::Middleware.register_middleware remove_cookies: Common::Client::Middleware::Request::RemoveCookies
Faraday::Middleware.register_middleware immutable_headers: Common::Client::Middleware::Request::ImmutableHeaders

Faraday::Request.register_middleware log_timeout_as_warning: Common::Client::Middleware::Request::LogTimeoutAsWarning

Faraday::Response.register_middleware hca_soap_parser: HCA::SOAPParser

# frozen_string_literal: true

class V0::Facilities::CcpController < FacilitiesController
  before_action :validate_id, only: [:show]

  def show
    ppms = Facilities::PPMSClient.new
    result = ppms.provider_info(params[:id])
    render json: result, serializer: ProviderSerializer
  end

  def specialties
    ppms = Facilities::PPMSClient.new
    result = ppms.specialties
    render json: result
  end

  private

  def validate_id
    if /^ccp_/ =~ params[:id]
      params[:id].sub!(/^ccp_/, '')
    else
      raise Common::Exceptions::InvalidFieldValue.new('id', params[:id])
    end
  end
end
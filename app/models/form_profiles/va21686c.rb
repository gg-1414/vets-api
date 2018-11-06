# frozen_string_literal: true

class ScrubbedString < Virtus::Attribute
  def coerce(value)
    ['NONE'].include?(value.to_s.upcase) ? '' : value
  end
end

module VA21686c
  class FormAddress
    include Virtus.model

    attribute :address_type, ScrubbedString
    attribute :street, ScrubbedString
    attribute :street2, ScrubbedString
    attribute :street3, ScrubbedString
    attribute :city, ScrubbedString
    attribute :state, ScrubbedString
    attribute :country, ScrubbedString
    attribute :postal_code, ScrubbedString
    attribute :country, ScrubbedString
    attribute :country_text, ScrubbedString
    attribute :post_office, ScrubbedString
    attribute :postal_type, ScrubbedString
  end

  class FormFullName
    include Virtus.model

    attribute :first, ScrubbedString
    attribute :middle, ScrubbedString
    attribute :last, ScrubbedString
  end

  class FormLocation
    include Virtus.model

    attribute :country_dropdown, ScrubbedString
    attribute :country_text, ScrubbedString
    attribute :city, ScrubbedString
    attribute :state, ScrubbedString
  end

  class FormDependent
    include Virtus.model

    attribute :full_name, VA21686c::FormFullName
    attribute :child_date_of_birth, ScrubbedString
    attribute :child_in_household, Boolean
    attribute :child_address, VA21686c::FormAddress
    attribute :child_social_security_number, ScrubbedString
    attribute :child_has_no_ssn, Boolean
    attribute :child_has_no_ssn_reason, ScrubbedString
    attribute :attending_college, Boolean
    attribute :disabled, Boolean
    attribute :married, Boolean
    attribute :place_of_birth, VA21686c::FormLocation
  end

  class FormMarriage
    include Virtus.model

    attribute :date_of_marriage, ScrubbedString
    attribute :location_of_marriage, VA21686c::FormLocation
    attribute :spouse_full_name, VA21686c::FormFullName
  end

  class FormCurrentMarriage < FormMarriage
    include Virtus.model

    attribute :spouse_social_security_number, ScrubbedString
    attribute :spouse_has_no_ssn, Boolean
    attribute :spouse_has_no_ssn_reason, ScrubbedString
    attribute :spouse_marriages, Array[VA21686c::FormMarriage]
    attribute :spouse_address, VA21686c::FormAddress
    attribute :spouse_is_veteran, Boolean
    attribute :live_with_spouse, Boolean
    attribute :spouse_date_of_birth, ScrubbedString
  end

  class FormContactInformation
    include Virtus.model

    attribute :veteran_address, VA21686c::FormAddress
    attribute :veteran_full_name, VA21686c::FormFullName
    attribute :veteran_email, ScrubbedString
    attribute :day_phone, ScrubbedString
    attribute :night_phone, ScrubbedString
    attribute :veteran_social_security_number, ScrubbedString
    attribute :current_marriage, VA21686c::FormMarriage
    attribute :previous_marriages, Array[VA21686c::FormMarriage]
    attribute :dependents, Array[VA21686c::FormDependent]
    attribute :va_file_number, ScrubbedString
    attribute :marital_status, ScrubbedString
  end
end

class FormProfiles::VA21686c < FormProfile
  attribute :veteran_information, VA21686c::FormContactInformation

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant-information'
    }
  end

  def prefill(user)
    return {} unless user.authorize :evss, :access?
    @veteran_information = initialize_veteran_information(user)
    super(user)
  end

  private

  def initialize_veteran_information(user)
    res = EVSS::Dependents::Service.new(user).retrieve
    veteran = res['submitProcess']['veteran']
    VA21686c::FormContactInformation.new(
      {
        veteran_address: prefill_address(veteran['address']),
        veteran_full_name: prefill_name(veteran),
        veteran_email: veteran['emailAddress'],
        va_file_number: detect_file_number(veteran['vaFileNumber']),
        marital_status: veteran['marriageType'],
        day_phone: convert_phone(veteran['primaryPhone']),
        night_phone: convert_phone(veteran['secondaryPhone']),
        veteran_social_security_number: convert_ssn(veteran['ssn']),
        current_marriage: prefill_current_marriage(veteran['spouse']),
        previous_marriages: veteran['previousMarriages'].map { |m| prefill_marriage(m) },
        dependents: prefill_dependents(veteran['children'])
      }.compact
    )
  end

  def convert_ssn(ssn)
    return unless ssn
    ssn.tr('^0-9', '')
  end

  def convert_phone(phone)
    return unless phone
    "#{phone['areaNbr']}#{phone['phoneNbr']}".tr('^0-9', '')
  end

  def prefill_current_marriage(spouse)
    return unless spouse
    marriage = spouse['currentMarriage']
    VA21686c::FormCurrentMarriage.new(
      {
        date_of_marriage: convert_date(marriage['marriageDate']),
        location_of_marriage: prefill_location(marriage['country'], marriage['city'], marriage['state']),
        spouse_full_name: prefill_name(spouse),
        spouse_social_security_number: convert_ssn(spouse['ssn']),
        spouse_has_no_ssn: spouse['hasNoSsn'],
        spouse_has_no_ssn_reason: spouse['noSsnReasonType'],
        spouse_marriages: spouse['previousMarriages'].map { |m| prefill_marriage(m) },
        spouse_address: prefill_address(spouse['address']),
        spouse_is_veteran: spouse['veteran'],
        live_with_spouse: spouse['sameResidency'],
        spouse_date_of_birth: convert_date(spouse['dateOfBirth'])
      }.compact
    )
  end

  def detect_file_number(file_number)
    return if file_number.nil? || file_number.match(/^\d{3}-\d{2}-\d{4}$/)
    file_number
  end

  def prefill_marriage(marriage)
    return unless marriage
    VA21686c::FormMarriage.new(
      {
        date_of_marriage: convert_date(marriage['marriageDate']),
        location_of_marriage: prefill_location(marriage['country'], marriage['city'], marriage['state']),
        spouse_full_name: prefill_name(marriage),
        reason_for_separation: marriage['marriageTerminationReasonType'],
        date_of_separation: convert_date(marriage['terminatedDate']),
        location_of_separation: prefill_location(marriage['endCountry'], marriage['endCity'], marriage['endState'])
      }.compact
    )
  end

  def prefill_location(country, city, state)
    country ||= {}
    VA21686c::FormLocation.new(
      {
        country_dropdown: country['dropDownCountry'],
        country_text: country['textCountry'],
        city: city,
        state: state
      }.compact
    )
  end

  def convert_date(date)
    return unless date
    Time.strptime(date.to_s, '%Q').utc.to_date.to_s
  end

  def prefill_dependents(children)
    return [] if children.blank?
    children.map do |child|
      VA21686c::FormDependent.new(
        {
          full_name: prefill_name(child),
          child_date_of_birth: convert_date(child['dateOfBirth']),
          child_in_household: child['sameResidency'],
          child_address: prefill_address(child['address']),
          child_social_security_number: convert_ssn(child['ssn']),
          child_has_no_ssn: child['hasNoSsn'],
          child_has_no_ssn_reason: child['noSsnReasonType'],
          attending_college: child['attendedSchool'],
          disabled: child['disabled'],
          married: child['married'],
          child_place_of_birth: prefill_location(child['countryOfBirth'], child['cityOfBirth'], child['stateOfBirth']),
          child_relationship_type: child['childRelationshipType']
        }.compact
      )
    end
  end

  def prefill_name(person)
    VA21686c::FormFullName.new(
      {
        first: person['firstName'],
        last: person['lastName'],
        middle: person['middleName']
      }.compact
    )
  end

  def prefill_address(address)
    return unless address
    address = VA21686c::FormAddress.new(
      {
        address_type: address['addressLocality'],
        street: address['addressLine1'],
        street2: address['addressLine2'],
        street3: address['addressLine3'],
        city: address['city'],
        state: address['state'],
        postal_code: "#{address['zipCode']}#{"-#{address['zipLastFour']}" if address['zipLastFour'].present?}",
        country: address.dig('country', 'dropDownCountry'),
        country_text: address.dig('country', 'textCountry'),
        post_office: address['postOffice'],
        postal_type: address['postalType']
      }.compact
    )
    return if address.attributes.values.uniq.all? { |x| ['DOMESTIC', ''].include? x }
    address
  end
end

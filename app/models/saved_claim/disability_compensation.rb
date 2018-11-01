# frozen_string_literal: true

class SavedClaim::DisabilityCompensation < SavedClaim
  has_one :disability_compensation_submission,
          class_name: 'DisabilityCompensationSubmission',
          inverse_of: :disability_compensation_claim,
          dependent: :destroy

  has_one :async_transaction,
          through: :disability_compensation_submission,
          source: :disability_compensation_job

  alias_attribute :submission, :disability_compensation_submission

  attr_accessor :form_hash

  FORM_526 = 'form526'
  FORM_526_UPLOADS = 'form526_uploads'
  FORM_4142 = 'form4142'
  FORM_0781 = 'form0781'

  def self.from_json(json)
    @form_hash = JSON.parse(json)
    saved_claim = new(form: @form_hash['form526'].to_json)
    saved_claim
  end

  # TODO(AJD): this could move to Form526Submission so constants aren't duplicated
  def to_submission_data(user)
    form4142 = EVSS::DisabilityCompensationForm::Form4142.new(user, @form_hash.deep_dup).translate
    form0781 = EVSS::DisabilityCompensationForm::Form0781.new(user, @form_hash.deep_dup).translate

    form526 = @form_hash.deep_dup
    form526 = append_overflow_text(form526) if form4142

    form526_uploads = form526['form526'].delete('attachments')

    # TODO: #translate_data can be removed once `increase only` has been deprecated
    {
      FORM_526 => translate_data(user, form526),
      FORM_526_UPLOADS => form526_uploads,
      FORM_4142 => form4142,
      FORM_0781 => form0781
    }.to_json
  end

  private

  def translate_data(_user, _form526)
    raise NotImplementedError, 'Subclass of DisabilityCompensation must implement #translate_data'
  end

  def append_overflow_text(form526)
    form526['form526']['overflowText'] = 'VA Form 21-4142/4142a has been completed by the applicant and sent to the ' \
      'PMR contractor for processing in accordance with M21-1 III.iii.1.D.2.'
    form526
  end
end

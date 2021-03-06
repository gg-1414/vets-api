# frozen_string_literal: true

class Form526Submission < ActiveRecord::Base
  attr_encrypted(:auth_headers_json, key: Settings.db_encryption_key)
  attr_encrypted(:form_json, key: Settings.db_encryption_key)

  belongs_to :saved_claim,
             class_name: 'SavedClaim::DisabilityCompensation',
             foreign_key: 'saved_claim_id'

  has_many :form526_job_statuses, dependent: :destroy

  FORM_526 = 'form526'
  FORM_526_UPLOADS = 'form526_uploads'
  FORM_4142 = 'form4142'
  FORM_0781 = 'form0781'

  def start(klass)
    workflow_batch = Sidekiq::Batch.new
    workflow_batch.on(
      :success,
      'Form526Submission#workflow_complete_handler',
      'submission_id' => id
    )
    jids = workflow_batch.jobs do
      klass.perform_async(id)
    end

    # submit form 526 is the first job in the batch
    # after it completes ancillary jobs may be added to the workflow batch
    # see #perform_ancillary_jobs below
    jids.first
  end

  def form
    @form_hash ||= JSON.parse(form_json)
  end

  def form_to_json(item)
    form[item].to_json
  end

  def auth_headers
    @auth_headers_hash ||= JSON.parse(auth_headers_json)
  end

  def perform_ancillary_jobs(bid)
    workflow_batch = Sidekiq::Batch.new(bid)
    workflow_batch.jobs do
      submit_uploads if form[FORM_526_UPLOADS].present?
      submit_form_4142 if form[FORM_4142].present?
      submit_form_0781 if form[FORM_0781].present?
      cleanup
    end
  end

  def workflow_complete_handler(_status, options)
    submission = Form526Submission.find(options['submission_id'])
    if submission.form526_job_statuses.all?(&:success?)
      submission.workflow_complete = true
      submission.save
    end
  end

  private

  def submit_uploads
    form[FORM_526_UPLOADS].each do |upload_data|
      EVSS::DisabilityCompensationForm::SubmitUploads.perform_async(id, upload_data)
    end
  end

  def submit_form_4142
    # TODO(AJD): update args to take only submission id
    CentralMail::SubmitForm4142Job.perform_async(
      submitted_claim_id, saved_claim_id, id, form_to_json(FORM_4142)
    )
  end

  def submit_form_0781
    # TODO(AJD): update args to take only submission id
    EVSS::DisabilityCompensationForm::SubmitForm0781.perform_async(
      auth_headers, submitted_claim_id, saved_claim_id, id, form_to_json(FORM_0781)
    )
  end

  def cleanup
    EVSS::DisabilityCompensationForm::SubmitForm526Cleanup.perform_async(id)
  end
end

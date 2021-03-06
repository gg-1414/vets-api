# frozen_string_literal: true

require 'pp'

namespace :form526 do
  desc 'Get all submissions within a date period. [<start date: yyyy-mm-dd>,<end date: yyyy-mm-dd>]'
  task :submissions, %i[start_date end_date] => [:environment] do |_, args|
    def print_row(created_at, updated_at, id, claim_id, complete)
      printf "%-24s %-24s %-15s %-10s %s\n", created_at, updated_at, id, claim_id, complete
    end

    start_date = args[:start_date] || 30.days.ago.utc.to_s
    end_date = args[:end_date] || Time.zone.now.utc.to_s

    print_row('created at:', 'updated at:', 'submission id:', 'claim id:', 'workflow complete:')

    Form526Submission.where('created_at BETWEEN ? AND ?', start_date, end_date)
                     .order(created_at: :desc)
                     .find_each do |s|
      print_row(s.created_at, s.updated_at, s.id, s.submitted_claim_id, s.workflow_complete)
    end
  end

  desc 'Get one or more submission details given an array of ids'
  task submission: :environment do |_, args|
    raise 'No submission ids provided' unless args.extras.count.positive?

    Rails.application.eager_load!

    args.extras.each do |id|
      submission = Form526Submission.find(id)

      saved_claim_form = JSON.parse(submission.saved_claim.form)
      saved_claim_form['veteran'] = 'FILTERED'

      auth_headers = JSON.parse(submission.auth_headers_json)

      puts '------------------------------------------------------------'
      puts "Submission (#{submission.id}):\n\n"
      puts "user uuid: #{submission.user_uuid}"
      puts "user edipi: #{auth_headers['va_eauth_dodedipnid']}"
      puts "user participant id: #{auth_headers['va_eauth_pid']}"
      puts "user ssn: #{auth_headers['va_eauth_pnid'].gsub(/(?=\d{5})\d/, '*')}"
      puts "saved claim id: #{submission.saved_claim_id}"
      puts "submitted claim id: #{submission.submitted_claim_id}"
      puts "workflow complete: #{submission.workflow_complete}"
      puts "created at: #{submission.created_at}"
      puts "updated at: #{submission.updated_at}"
      puts "\n"
      puts '----------------------------------------'
      puts "Jobs:\n\n"
      submission.form526_job_statuses.each do |s|
        puts s.job_class.to_s
        puts "  status: #{s.status}"
        puts "  error: #{s.error_class}" if s.error_class
        puts "    message: #{s.error_message}" if s.error_message
        puts "  updadated at: #{s.updated_at}"
        puts "\n"
      end
      puts '----------------------------------------'
      puts "Form JSON:\n\n"
      puts JSON.pretty_generate(saved_claim_form)
      puts "\n\n"
    end
  end

  def create_submission_hash(claim_id, submission, user_uuid)
    {
      user_uuid: user_uuid,
      saved_claim_id: submission.disability_compensation_id,
      submitted_claim_id: claim_id,
      auth_headers_json: { metadata: 'migrated data auth headers unavailable' }.to_json,
      form_json: { metadata: 'migrated data form unavailable' }.to_json,
      workflow_complete: submission.job_statuses.all? { |js| js.status == 'success' },
      created_at: submission.created_at,
      updated_at: submission.updated_at
    }
  end

  def create_status_hash(submission_id, job_status)
    {
      form526_submission_id: submission_id,
      job_id: job_status.job_id,
      job_class: job_status.job_class,
      status: job_status.status,
      error_class: nil,
      error_message: job_status.error_message,
      updated_at: job_status.updated_at
    }
  end

  desc 'update all disability compensation claims to have the correct type'
  task update_types: :environment do
    # `update_all` is being used because the `type` field will reset to `SavedClaim::DisabilityCompensation`
    # if a `claim.save` is done
    # rubocop:disable Rails/SkipsModelValidations
    SavedClaim::DisabilityCompensation.where(type: 'SavedClaim::DisabilityCompensation')
                                      .update_all(type: 'SavedClaim::DisabilityCompensation::Form526IncreaseOnly')
    # rubocop:enable Rails/SkipsModelValidations
  end

  desc 'dry run for migrating existing 526 submissions to the new tables'
  task migrate_dry_run: :environment do
    migrated = 0

    DisabilityCompensationSubmission.find_each do |submission|
      job = AsyncTransaction::EVSS::VA526ezSubmitTransaction.find(submission.va526ez_submit_transaction_id)
      user_uuid = job.user_uuid
      claim_id = nil
      claim_id = JSON.parse(job.metadata)['claim_id'] if job.transaction_status == 'received'

      submission_hash = create_submission_hash(claim_id, submission, user_uuid)

      puts "\n\n---"
      puts 'Form526Submission:'
      pp submission_hash

      submission.job_statuses.each do |job_status|
        status_hash = create_status_hash(nil, job_status)
        puts 'Form526JobStatus:'
        pp status_hash
      end

      migrated += 1
      puts "---\n\n"
    end

    puts "Submissions migrated: #{migrated}"
  end

  desc 'migrate existing 526 submissions to the new tables'
  task migrate_data: :environment do
    migrated = 0

    DisabilityCompensationSubmission.find_each do |submission|
      job = AsyncTransaction::EVSS::VA526ezSubmitTransaction.find(submission.va526ez_submit_transaction_id)
      user_uuid = job.user_uuid
      claim_id = nil
      claim_id = JSON.parse(job.metadata)['claim_id'] if job.transaction_status == 'received'

      new_submission = Form526Submission.create(create_submission_hash(claim_id, submission, user_uuid))

      submission.job_statuses.each do |job_status|
        Form526JobStatus.create(create_status_hash(new_submission.id, job_status))
      end

      migrated += 1
    end

    puts "Submissions migrated: #{migrated}"
  end
end

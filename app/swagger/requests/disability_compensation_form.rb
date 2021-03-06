# frozen_string_literal: true

module Swagger
  module Requests
    class DisabilityCompensationForm
      include Swagger::Blocks

      swagger_path '/v0/disability_compensation_form/rated_disabilities' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a list of previously rated disabilities for a veteran'
          key :operationId, 'getRatedDisabilities'
          key :tags, %w[form_526]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :RatedDisabilities
            end
          end
        end
      end

      swagger_path '/v0/disability_compensation_form/suggested_conditions{params}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Given part of a condition name (medical or lay), return a list of matching conditions'
          key :operationId, 'getSuggestedConditions'
          key :tags, %w[form_526]

          parameter :authorization

          parameter do
            key :name, :name_part
            key :description, 'part of a condition name'
            key :in, :path
            key :type, :string
            key :required, true
          end

          response 200 do
            key :description, 'Returns a list of conditions'
            schema do
              key :'$ref', :SuggestedConditions
            end
          end
        end
      end

      swagger_path '/v0/disability_compensation_form/submit' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Submit the disability compensation increase application for a veteran'
          key :operationId, 'postSubmitForm'
          key :tags, %w[form_526]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :SubmitDisabilityForm
            end
          end
        end
      end

      swagger_path '/v0/disability_compensation_form/submission_status/{job_id}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Check the status of a submission job'
          key :operationId, 'getSubmissionStatus'
          key :tags, %w[form_526]

          parameter :authorization

          parameter do
            key :name, :job_id
            key :description, 'the job_id for the submission to check the status of'
            key :in, :path
            key :type, :string
            key :required, true
          end

          response 200 do
            key :description, 'Returns the status of a given submission'
            schema do
              key :'$ref', :Form526JobStatus
            end
          end
        end
      end
    end
  end
end

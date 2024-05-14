#!/usr/bin/env ruby
require_relative '../../config/environment'

class CreateStripeSubscriptionsWithLinkingFile < DataScript

  # Do any setup / initialization for your script here
  def after_initialize
    @slug = options[:slug].strip
    @external_customer_id = options[:external_customer_id].strip
    @stripe_customer_id = options[:stripe_customer_id].strip
    @default_payment_method = options[:default_payment_method].strip
  end

  # Do the actual data processing here
  def process
    CurrentNation.with(@slug) do
      info "Processing subscription for Signup external_id: #{@external_customer_id}" if verbose?

      Signups::LinkRecurringDonationsToStripe.call({
        signup_external_id: @external_customer_id,
        stripe_customer_id: @stripe_customer_id,
        default_payment_method: @default_payment_method,
        validate_only: @dry_run
      })

      info "The subscription #{@dry_run ? 'is VALID' : 'has been CREATED'}." if verbose?
    end
  end
end

if $0 == __FILE__
  slop = Slop.parse(help: true, strict: true) do
    on 'd', 'dry_run',
      'Dry run mode - Validates the data by finding and creating the objects without saving them to the database.',
      default: true
    on 'w', 'write',
      'Write mode - i.e. The opposite of dry_run mode. This mode should actually make changes!'
    on 'v', 'verbose',
      'Log verbose output',
      default: false
    on 'slug=',
      'The slug of the nation you\'d like this import data to be applied to.',
      required: true
    on 'external_customer_id=',
      'The customer external ID.',
      required: true
    on 'stripe_customer_id=',
      'The stripe customer ID.',
      required: true
    on 'default_payment_method=',
      'The stripe payment method ID.',
      required: true
  end
  options = slop.to_hash
  options[:dry_run] = !options[:write] if options.key?(:write)

  CreateStripeSubscriptionsWithLinkingFile.run(options)
end

# To run this script for production, cd to the nbuild directory and run:
# RAILS_ENV=production ./script/rundeck/create_stripe_subscriptions_with_linking_file.rb

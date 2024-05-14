module Signups
  class LinkRecurringDonationsToStripe
    class Error < StandardError; end
    class SignupNotFoundError < Error; end
    class StripeConfigurationError < Error; end

    private_attr_reader :signup_external_id, :stripe_customer_id, :default_payment_method, :validate_only

    def self.call(...)
      new(...).call
    end

    def initialize(signup_external_id:, stripe_customer_id:, default_payment_method:, validate_only: false)
      @signup_external_id = signup_external_id
      @stripe_customer_id = stripe_customer_id
      @default_payment_method = default_payment_method,
      @validate_only = validate_only
    end

    def call
      signup = Signup.find_by(external_id: signup_external_id)

      if signup.nil?
        raise SignupNotFoundError.new(
          "Could not find Signup with an external id of '#{signup_external_id}' " +
            "while trying to link it to Stripe account '#{stripe_customer_id}'."
        )
      end

      recurring_donations_to_link = signup.recurring_donations.imported.pending

      recurring_donations_to_link.each do |recurring_donation|
        Payments::Stripe::LinkRecurringDonationToSubscription.call(
          stripe_customer_id: stripe_customer_id,
          default_payment_method: default_payment_method,
          recurring_donation: recurring_donation,
          validate_only: validate_only
        )
      end

      signup
    end
  end
end

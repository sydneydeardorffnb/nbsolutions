module Payments
  module Stripe
    class LinkRecurringDonationToSubscription
      include Payments::Stripe::ErrorHandling

      class Error < StandardError; end
      class NoPreviousPaymentError < Error; end
      class NoIntervalError < Error; end
      class MetaDataError < Error; end
      class ItemDataError < Error; end
      class SubscriptionCreationError < Error; end

      private_attr_reader :recurring_donation, :stripe_customer_id, :validate_only

      def self.call(...)
        new(...).call
      end

      def initialize(recurring_donation:, stripe_customer_id:, validate_only: false)
        @recurring_donation = recurring_donation
        @stripe_customer_id = stripe_customer_id
        @validate_only = validate_only
      end

      def call
        data = assemble_subscription_data
        return recurring_donation if validate_only

        subscription = create_stripe_subscription(data)

        recurring_donation.activate!(
          subscription.id,
          nil,
          next_bill_date: next_payment_date,
          last_pay_date: last_payment_date
        )

        recurring_donation
      end

      private

      def create_stripe_subscription(data)
        subscription = nil

        with_error_handling(error_response: :subscription_error, test_mode: stripe_config.test_mode?) do
          subscription = ::Stripe::Subscription.create(
            data,
            api_key: stripe_config.secret_key
          )
        end

        if subscription.try(:id).nil?
          raise SubscriptionCreationError.new(
            'There was a failure in trying to create a Stripe Subscription for some reason.'
          )
        end

        subscription
      end

      def assemble_subscription_data
        @stripe_subscription_data ||= {
          customer: stripe_customer_id,
          default_payment_method: default_payment_method,
          off_session: true,
          payment_behavior: 'allow_incomplete',
          trial_end: next_payment_date.to_i,
          metadata: metadata,
          items: [ item ],
          on_behalf_of: stripe_config.connected_stripe_account_id,
          transfer_data: {
            destination: stripe_config.connected_stripe_account_id
          }
        }
      end

      def next_payment_date
        @next_payment_date ||= last_payment_date + interval_count.send(interval)
      end

      def last_payment_date
        @last_payment_date ||= recurring_donation.last_successful_payment_date

        if @last_payment_date.nil?
          raise NoPreviousPaymentError.new(
            "For the Recurring Donation #{recurring_donation.id} " +
              'there was no previous successful payment date to determine the next payment date.'
          )
        end

        @last_payment_date
      end

      def metadata
        {
          nation_slug: CurrentNation.slug,
          environment: Rails.env
        }
      rescue => error
        raise MetaDataError.new(error.message)
      end

      def item
        {
          plan: Payments::Stripe::PlanRepository.new(stripe_config).get(interval, interval_count).id,
          quantity: recurring_donation.amount_in_cents
        }
      rescue => error
        raise ItemDataError.new(error.message)
      end

      def interval
        @interval ||= recurring_donation.time_period_type.downcase.singularize
      rescue => error
        raise NoIntervalError.new(
          "For the Recurring Donation #{recurring_donation.id} " +
            'there was an issue translating the time_period_type to a value Stripe can use.'
        )
      end

      def interval_count
        recurring_donation.num_time_periods
      end

      def stripe_config
        @stripe_config ||= Payments::StripeConfig.from_merchant_account(recurring_donation.merchant_account)
      end
    end
  end
end

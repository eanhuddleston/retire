module Finance
  def self.pretty(num)
    '$' + num.round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end

  ##
  # Code for finding a parameter value that will result in meeting the
  # desired future savings goal (in today's dollars, i.e., adjusted
  # for inflation), given that all other parameter values stay constant.
  #
  class ParameterSearch
    def self.good_high(sim_inputs: sim_inputs, search: search, goal: goal)
      current = 0.001
      while true
        sim_inputs[search] = current
        outcome = ContributionPhase.new(sim_inputs).after_inflation
        return current if outcome >= goal
        current *= 100
      end
    end

    def self.search(search: nil,
      goal: 250000,
      currently_saved: 0,
      yearly_contribution: 0,
      interest_rate: 0.06,
      inflation_rate: 0.03,
      savings_increase_rate: 0,
      years: 30)

      raise ArgumentError, 'Must specify value for search' unless search

      all_params = [:currently_saved, :yearly_contribution, :interest_rate, :inflation_rate,
          :savings_increase_rate, :years]
      
      puts ''
      puts "Using these parameters:"
      (all_params - [search]).each { |var| puts "#{var}: #{ eval(var.to_s) }" }
      puts ''

      sim_inputs = { currently_saved: currently_saved,
        yearly_contribution: yearly_contribution,
        interest_rate: interest_rate,
        inflation_rate: inflation_rate,
        savings_increase_rate: savings_increase_rate,
        years: years }
    
      # Set up initial search values
      low = 0
      high = good_high(sim_inputs: sim_inputs, search: search, goal: goal)
      mid = (high - low)/2

      acc = 0 if [:currently_saved, :yearly_contribution, :years].include?(search)
      acc = 3 if [:interest_rate, :inflation_rate, :savings_increase_rate].include?(search)

      while true
        sim_inputs[search] = mid
        s = ContributionPhase.new(sim_inputs)
        outcome_for_mid = s.after_inflation

        if low.round(acc) == high.round(acc) or 
            (mid == low) or (mid == high)
          puts "#{search} needed to reach #{ Finance::pretty(outcome_for_mid) } (for goal of #{Finance::pretty( goal )}):"
          return mid.round(acc)
        end

        # Adjust low and high for the next iteration
        if outcome_for_mid > goal
          low, high = low, mid
        elsif outcome_for_mid < goal
          low, high = mid, high
        end

        # Calculate new mid for next iteration
        mid = low + (high - low)/2.0
      end
    end
  end

  ##
  # High level class for running a simulation until retirement.
  #
  class ContributionPhase
    def initialize(currently_saved: 50000,
        yearly_contribution: 0,
        interest_rate: 0.06,
        inflation_rate: 0,
        savings_increase_rate: 0,
        years: 30)
      @currently_saved = currently_saved
      @yearly_contribution = yearly_contribution
      @interest_rate = interest_rate
      @inflation_rate = inflation_rate
      @savings_increase_rate = savings_increase_rate
      @years = years.round(0)
      self.run
    end

    def run
      @value_at_end_of_year = {}
      @value_at_end_of_year[0] = @currently_saved.to_f
      year_inputs = { base_value: 0,
                interest_rate: @interest_rate }

      # Fill in values for accumulation years
      (1..@years).each do |x|
        year_inputs[:base_value] = @value_at_end_of_year[x-1]
        # yearly_contribution will stay constant if @savings_increase_rate == 0
        year_inputs[:yearly_contribution] = @yearly_contribution * (1 + @savings_increase_rate)**x
        @value_at_end_of_year[x] = Finance::contribution_year(year_inputs)
      end
    end

    def data
      @value_at_end_of_year.map{ |k,v| [k, v.to_i] }
    end

    def data_as_hash
      @value_at_end_of_year.map{ |k,v| { 'age' => k, 'amount' => v.to_i } }
    end

    # def rounded_data
    #   s1.data.map{|y, v| "#{y}:#{v.pretty}"}.join(', ')
    # end

    def last
      @value_at_end_of_year.values.last.to_i
    end

    def after_inflation
      @value_at_end_of_year.values.last / ( 1 + @inflation_rate ) ** @years
    end
  end

  def self.contribution_year(base_value: 0,
      yearly_contribution: 0,
      interest_rate: 0,
      contribute_monthly: false)
    if contribute_monthly
      contribution_interest = InterestEarnedOnContribution.new(yearly_contribution, interest_rate).total
    else
      contribution_interest = 0
    end
    base_value * (1 + interest_rate) + yearly_contribution + contribution_interest
  end

  ##
  # Simulate the value in one account until death.
  #
  class DistributionPhase
    def initialize(starting_value: 3000000,
        withdrawal_rate: 0.04,
        interest_rate: 0.04,
        inflation_rate: 0.03,
        years: 30)
      @starting_value = starting_value
      @withdrawal_rate = withdrawal_rate
      @interest_rate = interest_rate
      @inflation_rate = inflation_rate
      @years = years
      self.run
    end

    def run
      @value_at_end_of_year = {}
      @value_at_end_of_year[0] = @starting_value.to_f

      year_inputs = { withdrawal: @starting_value * @withdrawal_rate,
          interest_rate: @interest_rate,
          inflation_rate: @inflation_rate }

      # Fill in values for distribution years
      (1..@years).each do |x|
        year_inputs[:start_value] = @value_at_end_of_year[x-1]
        # Adjust the withdrawal rate to keep pace with inflation
        year_inputs[:withdrawal] *= ( 1 + @inflation_rate ) if x > 1
        @value_at_end_of_year[x] = Finance::distribution_year(year_inputs)
      end
    end

    def final_value
      @value_at_end_of_year.values.last.to_i
    end
  end

 def self.distribution_year(start_value: 0,
      withdrawal: 0,
      interest_rate: 0.0,
      inflation_rate: 0.0)

    # Take out full withdrawal for year
    final_value = start_value - withdrawal
    # Calculate interest gained on this amount 
    final_value *= (1 + interest_rate)
    # Add back in interest from amounts of withdrawal left throughout
    # year (as it's not all withdrawn at once)
    final_value += InterestEarnedOnDistribution.new(withdrawal, interest_rate).total
    final_value
  end

  ##
  # The entire yearly distribution isn't taken out all at once, so the amount of it
  # that's left each month still earns interest. For example, if the yearly distribution
  # is 60k, then at the beginning of January, 5k will be taken out. But 55k of the 
  # distribution will still earn interest for the month of Jan. This class calculates,
  # for each month in the year, how much of the 60k is left and how much interest it
  # earns, then returns the sum of all the interest earned (on the distribution amount).
  #
  class InterestEarnedOnDistribution
    def initialize(yearly_distribution, interest_rate)
      @yearly_distribution = yearly_distribution
      @monthly_distribution = yearly_distribution/12
      @monthly_apr = interest_rate/12
    end

    def total
      @interest_earned_during_each_month = {}
      amount_of_distribution_remaining = @yearly_distribution
      
      (1..12).each do |x|
        # Subtract monthly distribution at beginning of month
        amount_of_distribution_remaining -= @monthly_distribution
        # Calculate how much interest was earned during month by remainder
        @interest_earned_during_each_month[x] = amount_of_distribution_remaining * @monthly_apr
      end

      # Return the total interest earned on the remaining parts of distribution throughout year
      @interest_earned_during_each_month.values.inject(:+)
    end

    def data
      @interest_earned_during_each_month
    end
  end

  ##
  # With monthly contributions, and assuming contributions are made at the beginning of the month,
  # this means that a contribution in Jan. will earn interest for the entire year, but a contribution 
  # in Dec. will earn interest for only one month. This class determines the total interest that 
  # has accumulated on monthly contributions at the end of the year.
  #
  class InterestEarnedOnContribution
    def initialize(yearly_contribution, interest_rate)
      @yearly_contribution = yearly_contribution
      @monthly_contribution = yearly_contribution/12.0
      @interest_rate = interest_rate
    end

    def total
      @interest_earned_from_each_contribution = {}
      (1..12).each do |x|
        @interest_earned_from_each_contribution[x] = @monthly_contribution * @interest_rate * ((13 - x) / 12.0)
      end
      @interest_earned_from_each_contribution.values.inject(:+)
    end

    def data
      @interest_earned_from_each_contribution
    end
  end
end




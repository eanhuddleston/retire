##
# Monkeypatch to create method for converting float into nicely formatted string
# with dollar sign at front and commas in correct places.
#
class Float
  def pretty
    '$' + self.round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end

##
# Code for finding a parameter value that will result in the
# desired savings goal (in today's dollars, i.e., adjusted
# for inflation), given that all other parameter values stay constant.
#
class ParameterSearch
  def self.search(goal: 250000,
      currently_saved: 0,
      yearly_contribution: 0,
      interest_rate: 0.06,
      inflation_rate: 0.03,
      savings_increase_rate: 0,
      years: 30)

    puts "Searching using these parameters:"
    ['currently_saved', 'yearly_contribution', 'interest_rate', 'inflation_rate',
        'savings_increase_rate', 'years', 'goal'].each do |var|
      puts "#{var}: #{ eval(var) }"
    end

    sim_inputs = { currently_saved: currently_saved,
      yearly_contribution: yearly_contribution,
      interest_rate: interest_rate,
      inflation_rate: inflation_rate,
      savings_increase_rate: savings_increase_rate,
      years: years }
  
    low = 0
    high = 10000000
    mid = (high - low)/2
    last_mid = 0

    while true
      # In finding the desired value, we don't care about fractions
      # of a dollar. Once we've narrowed our search down to the
      # dollar, call it good.
      if mid == last_mid
        puts "Amount needed to reach #{goal} in #{@years} years:"
        return mid.round(0)
      end

      last_mid = mid
      
      sim_inputs[:currently_saved] = mid
      outcome_for_mid = SimulateToRetirement.new(sim_inputs).after_inflation
      # puts "low: #{low}"
      # puts "mid: #{mid}"
      # puts "high: #{high}"
      # puts "out_come_for_mid: #{outcome_for_mid}"
      # puts "last_mid: #{last_mid}"
      # puts ""

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
class SimulateToRetirement
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
    @years = years
    self.run
  end

  def run
    @value_at_end_of_year = {}
    @value_at_end_of_year[0] = @currently_saved.to_f
    year_inputs = { base_value: 0,
              interest_rate: @interest_rate }

    # Fill in values for accumulation years
    year_inputs[:phase] = :contribution
    (1..@years).each do |x|
      year_inputs[:base_value] = @value_at_end_of_year[x-1]
      # yearly_contribution will stay constant if @savings_increase_rate == 0
      year_inputs[:yearly_contribution] = @yearly_contribution * (1 + @savings_increase_rate)**x
      @value_at_end_of_year[x] = Year.new(year_inputs).before_inflation
    end
  end

  def data
    @value_at_end_of_year.map{ |k,v| [k, v.to_i] }
  end

  def data_as_hash
    @value_at_end_of_year.map{ |k,v| { 'age' => k, 'amount' => v.to_i } }
  end

  def rounded_data
    s1.data.map{|y, v| "#{y}:#{v.pretty}"}.join(', ')
  end

  def last
    @value_at_end_of_year.values.last
  end

  def after_inflation
    @value_at_end_of_year.values.last / ( 1 + @inflation_rate ) ** @years
  end
end

##
# Class to do all the calculations for one year to determine what amount of money is left at 
# the end of the year taking into account all contributions, distributions, taxes, etc.
# Each Year object is instantiated with a 'phase', which can be either 'distribution'
# or 'contribution', indicating whether the current year is in the contribution or
# to the base_value from only inflation and/or interest earned.
#
class Year
  def initialize(base_value: 0,
        yearly_contribution: 0,
        yearly_distribution: 0,
        monthly_ss: 0,
        interest_rate: 0,
        distribution_tax_rate: 0,
        phase: :none,
        contribute_monthly: false)
    @base_value = base_value
    @yearly_contribution = yearly_contribution
    @yearly_distribution = yearly_distribution
    @monthly_ss = monthly_ss
    @interest_rate = interest_rate
    @distribution_tax_rate = distribution_tax_rate
    @phase = phase
    @contribute_monthly = contribute_monthly
  end

  ##
  # Returns the amount of money left at the end of the year before inflation has been considered.
  #
  def before_inflation
    if @phase == :none
      return @base_value * (1 + @interest_rate) if @interest_rate > 0  # earning interest
      return @base_value  # not earning interest
    elsif @phase == :contribution
      if @contribute_monthly
        contribution_interest = InterestEarnedOnContribution.new(@yearly_contribution, @interest_rate).total
      else
        contribution_interest = 0
      end
      @base_value * (1 + @interest_rate) + @yearly_contribution + contribution_interest
    elsif @phase == :distribution
      monthly_ss_after_taxes = @monthly_ss * (1 - @distribution_tax_rate)
      yearly_ss_after_taxes = monthly_ss_after_taxes * 12
      # Don't need to take out full amount needed, as some provided by SS
      yearly_distribution_minus_ss_contribution = @yearly_distribution - yearly_ss_after_taxes
      # But, of that needed after SS, need to take out enough to pay for taxes (and still have desired amount left)
      yearly_distribution_after_tax_correction = yearly_distribution_minus_ss_contribution / (1 - @distribution_tax_rate)
      value_of_base_minus_distribution_plus_interest = ( @base_value - yearly_distribution_after_tax_correction ) * (1 + @interest_rate)
      distribution_interest = InterestEarnedOnDistribution.new(yearly_distribution_after_tax_correction, @interest_rate).total
      value_of_base_minus_distribution_plus_interest + distribution_interest
    end
  end
end

class SimulateToDeath
  def initialize(taxable_accounts: 3000000,
      nontaxable_accounts: 1000000,
      withdrawal_rate: 0.04,
      interest_rate: 0.04,
      inflation_rate: 0.03,
      years: 30)
    @taxable_accounts = taxable_accounts
    @nontaxable_accounts = nontaxable_accounts
    @withdrawal_rate = withdrawal_rate
    @interest_rate = interest_rate
    @inflation_rate = inflation_rate
    @years = years
    self.run
  end

  def run
    @taxable_value_at_end_of_year = {}
    @nontaxable_value_at_end_of_year = {}
    @taxable_value_at_end_of_year[0] = @taxable_accounts.to_f
    @nontaxable_value_at_end_of_year[0] = @nontaxable_accounts.to_f

    taxable_withdrawal = @taxable_accounts * @withdrawal_rate
    nontaxable_withdrawal = @nontaxable_accounts * @withdrawal_rate

    taxable_year_inputs = { withdrawal: taxable_withdrawal,
        interest_rate: @interest_rate,
        inflation_rate: @inflation_rate }

    nontaxable_year_inputs = { withdrawal: nontaxable_withdrawal,
        interest_rate: @interest_rate,
        inflation_rate: @inflation_rate }

    # Fill in values for distribution years
    (1..@years).each do |x|
      taxable_year_inputs[:start_value] = @taxable_value_at_end_of_year[x-1]
      taxable_year_inputs[:years_since_retirement] = x
      @taxable_value_at_end_of_year[x] = DistributionYear.new(taxable_year_inputs).final_value

      nontaxable_year_inputs[:start_value] = @nontaxable_value_at_end_of_year[x-1]
      nontaxable_year_inputs[:years_since_retirement] = x
      @nontaxable_value_at_end_of_year[x] = DistributionYear.new(nontaxable_year_inputs).final_value
    end
  end

  def final_values
    { taxable: @taxable_value_at_end_of_year.values.last, 
        nontaxable: @nontaxable_value_at_end_of_year.values.last }
  end
end

class DistributionYear
  def initialize(start_value: 3000000,
      withdrawal: 90000,
      years_since_retirement: 0,
      interest_rate: 0.04,
      inflation_rate: 0.03)
    @start_value = start_value
    @withdrawal = withdrawal
    @years_since_retirement = years_since_retirement
    @interest_rate = interest_rate
    @inflation_rate = inflation_rate
  end

  def final_value
    adjusted_withdrawal = @withdrawal * ( 1 + @inflation_rate ) ** @years_since_retirement
    # Take out full withdrawal for year
    final_value = @start_value - adjusted_withdrawal
    # Calculate interest gained on this amount 
    final_value *= (1 + @interest_rate)
    # Add back in interest from amounts of withdrawal left throughout
    # year (as it's not all withdrawn at once)
    final_value += InterestEarnedOnDistribution.new(adjusted_withdrawal, @interest_rate).total
    final_value
  end
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

class Comparison
  def initialize(currently_saved, yearly_contribution, yearly_distribution, monthly_ss)
    @currently_saved = currently_saved
    @yearly_contribution = yearly_contribution
    @yearly_distribution = yearly_distribution
    @monthly_ss = monthly_ss
    @interest_rate = {}
    @interest_rate[:worst] = 0.04
    @interest_rate[:likely] = 0.06
    @interest_rate[:best] = 0.08
    @inflation_rate = {}
    @inflation_rate[:worst] = 0.05
    @inflation_rate[:likely] = 0.0325
    @inflation_rate[:best] = 0.02
    @age_retire = {}
  end

  def run
    value_at_death = {}

    [:worst, :likely, :best].each do |situation|
      simulation = Simulation.new(
          currently_saved: @currently_saved,
          yearly_contribution: @yearly_contribution,
          yearly_distribution: @yearly_distribution,
          distribution_tax_rate: 0.15,
          monthly_ss: @monthly_ss,
          interest_rate: @interest_rate[situation],
          inflation_rate: @inflation_rate[situation],
          age_now: 36,
          age_retire: 70,
          age_die: 92)

      simulation.run
      value_at_death[situation] = simulation.last.pretty
    end

    puts "Worst case: #{ value_at_death[:worst] }"
    puts "Likely case: #{ value_at_death[:likely] }"
    puts "Best case: #{ value_at_death[:best] }"
  end
end

# c = Comparison.new(40000, 20000, 74000, 3000)
# c.run

# s1 = Simulation.new(currently_saved: 40000,
#     yearly_contribution: 20000,
#     yearly_distribution: 74000,
#     distribution_tax_rate: 0.15,
#     monthly_ss: 3000,
#     interest_rate: 0.06,
#     inflation_rate: 0.0325,
#     age_now: 36,
#     age_retire: 65,
#     age_die: 95)
# s1.run
# s1.data.each{|y, v| puts "#{y}: #{v}"}




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
# High level class for actually running one full retirement simulation, given all input parameters.
#
class Simulation
  def initialize(currently_saved: 80000,
        yearly_contribution: 15000,
        yearly_distribution: 100000,
        distribution_tax_rate: 0.25,
        monthly_ss: 1000,
        apr: 0.06,
        inflation_rate: 0.0325,
        age_now: 25,
        age_retire: 65,
        age_die: 90)
    unless age_now < age_retire and age_retire < age_die
      raise RuntimeError.new 'Get your ages straight, man'
    end
    @currently_saved = currently_saved
    @yearly_contribution = yearly_contribution
    @yearly_distribution = yearly_distribution
    @distribution_tax_rate = distribution_tax_rate
    @monthly_ss = monthly_ss
    @apr = apr
    @inflation_rate = inflation_rate
    @age_now = age_now
    @age_retire = age_retire
    @age_die = age_die
  end

  def run
    @value_at_end_of_year = {}
    @value_at_end_of_year[@age_now] = @currently_saved.to_f
    # Fill in values for accumulation years
    (@age_now+1..@age_retire).each do |x|
      @value_at_end_of_year[x] = Year.new(@value_at_end_of_year[x-1], @yearly_contribution, 0, 0, @apr, @inflation_rate, @distribution_tax_rate).after_inflation
    end

    # Fill in values for distribution years
    (@age_retire+1..@age_die).each do |x|
      @value_at_end_of_year[x] = Year.new(@value_at_end_of_year[x-1], 0, @yearly_distribution, @monthly_ss, @apr, @inflation_rate, @distribution_tax_rate).after_inflation
    end
  end

  def data
    @value_at_end_of_year
  end

  def rounded_data
    s1.data.map{|y, v| "#{y}:#{v.pretty}"}.join(', ')
  end

  def last
    @value_at_end_of_year.values.last
  end
end

##
# Class to do all the calculations for one year to determine what amount of money is left at 
# the end of the year taking into account all contributions, distributions, taxes, etc.
#
class Year
  def initialize(base_value, yearly_contribution, yearly_distribution, monthly_ss, apr, inflation_rate, distribution_tax_rate)
    @base_value = base_value
    @yearly_contribution = yearly_contribution
    @yearly_distribution = yearly_distribution
    @monthly_ss = monthly_ss
    @apr = apr
    @inflation_rate = inflation_rate
    @distribution_tax_rate = distribution_tax_rate
  end

  ##
  # Returns the amount of money left at the end of the year before inflation has been considered.
  #
  def before_inflation
    if @yearly_contribution > 0 # in contribution phase
      contribution_interest = InterestEarnedOnContribution.new(@yearly_contribution, @apr).total
      @base_value * (1 + @apr) + @yearly_contribution + contribution_interest
    elsif @yearly_distribution > 0 # in distribution phase
      monthly_ss_after_taxes = @monthly_ss * (1 - @distribution_tax_rate)
      yearly_ss_after_taxes = monthly_ss_after_taxes * 12
      # Don't need to take out full amount needed, as some provided by SS
      yearly_distribution_minus_ss_contribution = @yearly_distribution - yearly_ss_after_taxes
      # But, of that needed after SS, need to take out enough to pay for taxes (and still have desired amount left)
      yearly_distribution_after_tax_correction = yearly_distribution_minus_ss_contribution / (1 - @distribution_tax_rate)
      value_of_base_minus_distribution_plus_interest = ( @base_value - yearly_distribution_after_tax_correction ) * (1 + @apr)
      distribution_interest = InterestEarnedOnDistribution.new(yearly_distribution_after_tax_correction, @apr).total
      value_of_base_minus_distribution_plus_interest + distribution_interest
    end
  end

  def after_inflation
    self.before_inflation / (1 + @inflation_rate)
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
  def initialize(yearly_distribution, apr)
    @yearly_distribution = yearly_distribution
    @monthly_distribution = yearly_distribution/12
    @monthly_apr = apr/12
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
end

##
# Contributions are likely made monthly, not yearly. This means that a contribution in Jan.
# will earn interest for the entire year, but a contribution in Dec. will earn interest for
# only one month. This class determines, for contributions made throughout the year, what interest 
# has accumulated on them.
#
class InterestEarnedOnContribution
  def initialize(yearly_contribution, apr)
    @yearly_contribution = yearly_contribution
    @monthly_contribution = yearly_contribution/12.0
    @apr = apr
  end

  def total
    @interest_earned_from_each_contribution = {}
    (1..12).each do |x|
      @interest_earned_from_each_contribution[x] = @monthly_contribution * @apr * ((12 - x) / 12.0)
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
    @apr = {}
    @apr[:worst] = 0.04
    @apr[:likely] = 0.06
    @apr[:best] = 0.08
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
          apr: @apr[situation],
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

c = Comparison.new(40000, 20000, 74000, 3000)
c.run


# s1 = Simulation.new(currently_saved: 40000,
#     yearly_contribution: 20000,
#     yearly_distribution: 74000,
#     distribution_tax_rate: 0.15,
#     monthly_ss: 3000,
#     apr: 0.06,
#     inflation_rate: 0.0325,
#     age_now: 36,
#     age_retire: 65,
#     age_die: 95)
# s1.run
# s1.data.each{|y, v| puts "#{y}: #{v}"}




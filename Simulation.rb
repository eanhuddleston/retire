class Float
  def pretty
    '$' + self.round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end

class Simulation
  def initialize(principle, yearly_contribution, yearly_distribution, apr, inflation_rate, age_now, age_retirement, age_death)
    unless age_now < age_retirement and age_retirement < age_death
      raise RuntimeError.new 'Get your ages straight, man'
    end
    @principle = principle
    @yearly_contribution = yearly_contribution
    @yearly_distribution = yearly_distribution
    @apr = apr
    @inflation_rate = inflation_rate
    @age_now = age_now
    @age_retirement = age_retirement
    @age_death = age_death
  end

  def run
    @value_at_end_of_year = {}
    @value_at_end_of_year[@age_now] = @principle.to_f
    # Fill in values for accumulation years
    (@age_now+1..@age_retirement).each do |x|
      @value_at_end_of_year[x] = Year.new(@value_at_end_of_year[x-1], @yearly_contribution, 0, @apr, @inflation_rate).after_inflation
    end

    # Fill in values for distribution years
    (@age_retirement+1..@age_death).each do |x|
      @value_at_end_of_year[x] = Year.new(@value_at_end_of_year[x-1], 0, @yearly_distribution, @apr, @inflation_rate).after_inflation
    end
  end

  def data
    @value_at_end_of_year
  end

  def last
    @value_at_end_of_year.values.last
  end
end

class Year
  def initialize(base_value, yearly_contribution, yearly_distribution, apr, inflation_rate)
    @base_value = base_value
    @yearly_contribution = yearly_contribution
    @yearly_distribution = yearly_distribution
    @apr = apr
    @inflation_rate = inflation_rate
  end

  def before_inflation
    if @yearly_contribution > 0 # in contribution phase
      contribution_interest = InterestEarnedOnContribution.new(@yearly_contribution, @apr).total
      @base_value * (1 + @apr) + @yearly_contribution + contribution_interest
    elsif @yearly_distribution > 0 # in distribution phase
      value_of_base_minus_distribution_plus_interest = ( @base_value - @yearly_distribution ) * (1 + @apr)
      distribution_interest = InterestEarnedOnDistribution.new(@yearly_distribution, @apr).total
      value_of_base_minus_distribution_plus_interest + distribution_interest
    end
  end

  def after_inflation
    self.before_inflation / (1 + @inflation_rate)
  end
end

##
# The entire yearly distribution isn't taken out all once, so the amount of it
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



# d = InterestEarnedOnDistribution.new(60000, 0.06)
# puts d.total

# y = Year.new(60000, 0, 60000, 0.06, 0.03)
# puts y.after_inflation

# puts Year.new(0.0, 10, 0, 0.1, 0).after_inflation
# i =  InterestEarnedOnContribution.new(10, 0.1)
# i.total
# p i.data

s1 = Simulation.new(0, 10, 20, 0.1, 0, 20, 30, 40)
s1.run
# puts s1.data.map{|y, v| "#{y}:#{v.pretty}"}.join(', ')

s1.data.each{|y, v| puts "#{y}: #{v}"}

# x = 0.01
# 400.times{
#   s = Simulation.new(0, 10, 12, x, 0.0325, 36, 65, 95)
#   s.run
#   x += 0.001
# }

# Compare.new(40000, 20000).go(30)

# puts Simulation.new(40000, 20000, 0.08, 0.03, 30).simulate.pretty
# c = Simulation.new(40000, 20000, 0.06, 0.04, 30)
# puts c.simulate

# y = Year.new(40000, 0, 0.06, 0.02)
# puts y.after_inflation

# t = Contributions.new(1200, 0.06)
# puts t.total


# end

# class Compare
#   def initialize(principle, yearly_contribution)
#     @principle = principle
#     @yearly_contribution = yearly_contribution
#     @apr_worst = 0.04
#     @inflation_worst = 0.04
#     @apr_likely = 0.06
#     @inflation_likely = 0.0325
#     @apr_best = 0.08
#     @inflation_best = 0.01
#   end

#   def go(years)
#     worst = Simulation.new(@principle, @yearly_contribution, @apr_worst, @inflation_worst, years).run
#     likely = Simulation.new(@principle, @yearly_contribution, @apr_likely, @inflation_likely, years).run
#     best = Simulation.new(@principle, @yearly_contribution, @apr_best, @inflation_best, years).run
#     puts "Worst case: #{ worst.pretty }"
#     puts "Likely case: #{ likely.pretty }"
#     puts "Best case: #{ best.pretty }"
#   end
# end


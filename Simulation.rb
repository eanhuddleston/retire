class Float
  def pretty
    '$' + self.round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end

class Simulation
  attr_reader :principle, :yearly_contribution, :apr, :inflation_rate, :years

  def initialize(principle, yearly_contribution, apr, inflation_rate, years)
    @principle = principle
    @yearly_contribution = yearly_contribution
    @apr = apr
    @inflation_rate = inflation_rate
    @years = years
  end

  def run
    @value_at_end_of_year = {}
    @value_at_end_of_year[1] = Year.new(principle, yearly_contribution, apr, inflation_rate).after_inflation
    years > 1 and (2..years).each do |x|
      @value_at_end_of_year[x] = Year.new(@value_at_end_of_year[x-1], yearly_contribution, apr, inflation_rate).after_inflation
    end
    @value_at_end_of_year[years]
  end

  def data
    @value_at_end_of_year.values
  end
end

class Year
  attr_reader :base_value, :yearly_contribution, :apr, :inflation_rate

  def initialize(base_value, yearly_contribution, apr, inflation_rate)
    @base_value = base_value
    @yearly_contribution = yearly_contribution
    @apr = apr
    @inflation_rate = inflation_rate
  end

  def before_inflation
    base_value * (1 + apr) + Contributions.new(yearly_contribution, apr).total
  end

  def after_inflation
    self.before_inflation / (1 + inflation_rate)
  end
end

class Contributions
  attr_reader :interest_earned_from_each_contribution

  def initialize(yearly_contribution, apr)
    @yearly_contribution = yearly_contribution
    @monthly_contribution = yearly_contribution/12
    @apr = apr
  end

  def total
    @interest_earned_from_each_contribution = {}
    (1..12).each do |x|
      @interest_earned_from_each_contribution[x] = @monthly_contribution * @apr * ((12 - x) / 12.0)
    end
    @interest_earned_from_each_contribution.values.inject(:+) + @yearly_contribution
  end
end

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


# Compare.new(40000, 20000).go(30)

s1 = Simulation.new(40000, 20000, 0.06, 0.02, 30)
s1.run
p s1.data.map{|d| d.pretty}.join(', ')



# puts Simulation.new(40000, 20000, 0.08, 0.03, 30).simulate.pretty
# c = Simulation.new(40000, 20000, 0.06, 0.04, 30)
# puts c.simulate

# y = Year.new(40000, 0, 0.06, 0.02)
# puts y.after_inflation

# t = Contributions.new(1200, 0.06)
# puts t.total



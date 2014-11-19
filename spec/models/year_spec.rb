require 'spec_helper'
require 'simulation'
require 'pry'

describe InterestEarnedOnContribution do
  it "calculates the interest earned on contributions made throughout the year" do
    expect( InterestEarnedOnContribution.new(12, 0.1).total.round(2) ).to eq(0.65)
    # Each number represents the interest earned by that month's distribution during
    # the remainder of the year:
    # monthly data: [0.1, 0.0917, 0.0833, 0.075, 0.0667, 0.0583, 0.05, 0.0417, 0.0333, 0.025, 0.0167, 0.0083]
  end
end

describe InterestEarnedOnDistribution do
  it "calculates the interest earned on a yearly distribution that's withdrawn monthly" do
    expect( InterestEarnedOnDistribution.new(12, 0.1).total.round(2) ).to eq(0.55)
    # Each number represents the interest earned during *that month* on whatever remains
    # of distribution:
    # [0.0917, 0.0833, 0.075, 0.0667, 0.0583, 0.05, 0.0417, 0.0333, 0.025, 0.0167, 0.0083, 0.0]
  end
end

describe Year do
  let(:inputs) { { base_value: 100,
        yearly_contribution: 0,
        yearly_distribution: 0,
        monthly_ss: 0,
        apr: 0,
        inflation_rate: 0,
        distribution_tax_rate: 0,
        phase: :none } }

  context 'before inflation' do
    it "adds the yearly contribution to the base value" do
      inputs[:yearly_contribution] = 10
      inputs[:phase] = :contribution
      expect(Year.new(inputs).before_inflation).to eq(110)
    end

    it "removes the yearly distribution from the base value" do
      inputs[:yearly_distribution] = 10
      inputs[:phase] = :distribution
      expect(Year.new(inputs).before_inflation).to eq(90)
    end
  end

  context 'after inflation' do
    it "returns the value of the base value after inflation" do
      inputs[:inflation_rate] = 0.1
      expect(Year.new(inputs).after_inflation.round(2)).to eq(90.91)
    end

    context 'with contribution' do
      it "returns the value of the base value + contribution, after inflation" do
        inputs[:yearly_contribution] = 10
        inputs[:phase] = :contribution
        inputs[:inflation_rate] = 0.1
        expect(Year.new(inputs).after_inflation.round(2)).to eq(100)
      end
    end
  end

end
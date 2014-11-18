require 'spec_helper'
require 'simulation'
require 'pry'

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
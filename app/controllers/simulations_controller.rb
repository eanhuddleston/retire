class SimulationsController < ApplicationController
  require 'simulation'

  def index

  end

  def run
    s1 = Simulation.new(currently_saved: params[:currently_saved].to_f,
        yearly_contribution: params[:yearly_contribution].to_f,
        yearly_distribution: params[:yearly_distribution].to_f,
        distribution_tax_rate: params[:distribution_tax_rate].to_f,
        monthly_ss: params[:monthly_ss].to_f,
        apr: params[:apr].to_f,
        inflation_rate: params[:inflation_rate].to_f,
        age_now: params[:age_now].to_i,
        age_retire: params[:age_retire].to_i,
        age_die: params[:age_die].to_i)
    s1.run
    @data = s1.data
    gon.data = s1.data_as_hash
  end
end
